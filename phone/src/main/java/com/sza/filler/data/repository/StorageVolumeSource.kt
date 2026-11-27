package com.sza.filler.data.repository

import android.content.Context
import android.os.Build
import android.os.Environment
import android.os.StatFs
import android.os.storage.StorageManager
import android.os.storage.StorageVolume
import android.util.Log
import com.sza.filler.domain.model.StorageVolumeInfo

// Ported from FastMediaSorter release 48 (data/repository/StorageVolumeSource.kt). Deliberate differences:
// - no Hilt: the surface constructs one PlatformStorageVolumeSource with the application context;
// - android.util.Log instead of Timber, which this app does not carry;
// - the API 23 branches are gone: minSdk is 26 here, so StorageManager.getStorageVolumes() always exists;
// - the source's mention of its StorageVolumeRepositoryImpl and UriPathResolver consumers is dropped,
//   neither exists in this app.

/**
 * Blocking access to the platform's storage volumes, and the seam unit tests drive with a fake.
 */
interface StorageVolumeSource {

    /** Every volume the platform reports, unmounted ones included. Blocking - never call on Main. */
    fun listVolumes(): List<StorageVolumeInfo>

    /**
     * Mount path of [volumeId] without reading usage counters.
     *
     * Cheap enough for a Main-thread call: it asks the mount service for the volume list and reads
     * the directory, but never touches [StatFs].
     */
    fun mountPathFor(volumeId: String): String?
}

/**
 * [StorageVolumeSource] over `StorageManager`.
 *
 * This class owns the only `StorageVolume.getPath()` reflection in the project: the official
 * `getDirectory()` exists from API 30 only, and below it the hidden getter is the sole way to learn
 * a removable volume's mount point. Keeping it here means the OEM-variance risk sits at one call
 * site instead of being copied per consumer.
 */
class PlatformStorageVolumeSource(private val context: Context) : StorageVolumeSource {

    private val storageManager: StorageManager
        get() = context.getSystemService(Context.STORAGE_SERVICE) as StorageManager

    // Broad by necessity: a volume is described by the mount service, and OEM builds have been seen
    // to throw anything from a dying card - the contract is that one hostile volume costs the caller
    // that volume, never the whole list.
    @Suppress("TooGenericExceptionCaught")
    override fun listVolumes(): List<StorageVolumeInfo> =
        platformVolumes().mapNotNull { volume ->
            try {
                toInfo(volume)
            } catch (e: Exception) {
                Log.w(LOG_TAG, "Skipping volume uuid=${volume.uuid}", e)
                null
            }
        }

    override fun mountPathFor(volumeId: String): String? = when {
        volumeId.equals(StorageVolumeInfo.PRIMARY_VOLUME_ID, ignoreCase = true) ->
            Environment.getExternalStorageDirectory()?.absolutePath
        else -> platformVolumes()
            .firstOrNull { it.uuid?.equals(volumeId, ignoreCase = true) == true }
            ?.takeIf { it.state == Environment.MEDIA_MOUNTED }
            ?.let { volumePath(it) }
    }

    // Same reasoning as listVolumes: an unreadable mount service must degrade to "no volumes"
    // rather than take down the caller's screen.
    @Suppress("TooGenericExceptionCaught")
    private fun platformVolumes(): List<StorageVolume> =
        try {
            storageManager.storageVolumes
        } catch (e: Exception) {
            Log.w(LOG_TAG, "Storage volume enumeration failed", e)
            emptyList()
        }

    private fun toInfo(volume: StorageVolume): StorageVolumeInfo {
        val mounted = volume.state == Environment.MEDIA_MOUNTED
        val path = if (mounted) volumePath(volume) else null
        val usage = path?.let { readUsage(it) }
        return StorageVolumeInfo(
            id = if (volume.isPrimary) StorageVolumeInfo.PRIMARY_VOLUME_ID else volume.uuid.orEmpty(),
            displayName = volume.getDescription(context).orEmpty(),
            isRemovable = volume.isRemovable,
            isMounted = mounted,
            mountPath = path,
            totalBytes = usage?.first ?: 0L,
            availableBytes = usage?.second ?: 0L
        )
    }

    /** Capacity and free bytes of [path], or null when the volume disappeared between the calls. */
    private fun readUsage(path: String): Pair<Long, Long>? =
        try {
            val stat = StatFs(path)
            stat.totalBytes to stat.availableBytes
        } catch (e: IllegalArgumentException) {
            // StatFs rejects a path that vanished between the enumeration and this call.
            Log.w(LOG_TAG, "Usage unavailable for $path", e)
            null
        }

    private fun volumePath(volume: StorageVolume): String? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val directoryPath = volume.directory?.absolutePath
            if (!directoryPath.isNullOrBlank()) {
                return directoryPath
            }
        }
        return try {
            volume.javaClass.getMethod("getPath").invoke(volume) as? String
        } catch (e: ReflectiveOperationException) {
            Log.w(LOG_TAG, "Reflection failed for StorageVolume.getPath()", e)
            null
        }
    }

    private companion object {
        const val LOG_TAG = "StorageVolumeSource"
    }
}

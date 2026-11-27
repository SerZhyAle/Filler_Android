package com.sza.filler.wear.data

import android.content.Context
import android.net.Uri
import android.os.Environment
import android.os.StatFs
import com.sza.filler.data.filler.FillerJournalEntry
import com.sza.filler.data.filler.FillerSessionJournal
import com.sza.filler.domain.filler.FillerFile
import com.sza.filler.domain.filler.FillerPlace
import com.sza.filler.domain.filler.FillerSession
import com.sza.filler.domain.filler.FillerStorage
import com.sza.filler.domain.filler.FillerTarget
import com.sza.filler.domain.filler.FillerTargetResolver
import com.sza.filler.wear.R
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.util.UUID
import kotlin.random.Random

// The watch storage adapter (S0019), ported from FastMediaSorter release 48 through the phone's port
// (data/filler/AppFillerStorage.kt and the app-owned branch of LocalFillerStorage.kt, S4521). Deliberate differences:
// - one location only, the app-owned Downloads directory of the watch's internal storage. Choosing another
//   folder, removable storage included, is not offered: Wear OS establishes no system folder picker and the
//   watch has one internal volume (S0017 research note section 7, row 2, "cannot", Assumed A1; settled on the
//   watch by the open checks O1 and O2 of S0020). So there is no document-tree branch, grant() always refuses,
//   and there is no StorageVolumeSource: the place is named by this module's string, not by a volume list;
// - the adapter implements FillerStorage and FillerTargetResolver itself; on the phone LocalFillerStorage does and
//   delegates the app-owned location to AppFillerStorage.
// The location "filler://app-downloads", the session directory ".filler-<uuid>", the file names, the
// session-owned-only cleanup and the discarding of a precommitted create (S0049) are the phone's, unchanged:
// a fix to one is made to both (docs/SPECIFICATION_SYNC_MODEL.md).

/** Fills the app-owned Downloads directory of the watch; needs no permission and no grant. */
class WatchFillerStorage(
    private val context: Context,
    private val journal: FillerSessionJournal,
) : FillerStorage, FillerTargetResolver {

    override suspend fun defaultLocation(): String? = withContext(Dispatchers.IO) {
        if (root() != null) LOCATION else null
    }

    /** No folder picker exists to hand over another location (S0017 row 2), so nothing else is ever granted. */
    override suspend fun grant(location: String): Boolean = false

    override suspend fun place(location: String): FillerPlace? = withContext(Dispatchers.IO) {
        if (location != LOCATION) return@withContext null
        val directory = root() ?: return@withContext null
        FillerPlace(target(), context.getString(R.string.filler_watch_storage), directory.absolutePath)
    }

    override suspend fun validate(target: FillerTarget): Boolean = withContext(Dispatchers.IO) {
        val directory = root()
        target == target() && directory != null && directory.isDirectory && directory.canWrite() &&
            Environment.getExternalStorageState(directory) == Environment.MEDIA_MOUNTED
    }

    override suspend fun availableBytes(target: FillerTarget): Long? = withContext(Dispatchers.IO) {
        if (!validate(target)) return@withContext null
        try {
            root()?.let { StatFs(it.path).availableBytes }
        } catch (_: IllegalArgumentException) {
            null
        }
    }

    override suspend fun create(session: FillerSession, index: Int): FillerFile = withContext(Dispatchers.IO) {
        check(validate(session.target))
        val parent = root() ?: throw IOException("App storage unavailable")
        val directory = sessionDirectory(parent, session)
        if (journal.entry(session).directory == null) {
            if (!directory.mkdir()) throw IOException("Cannot create session directory")
            journal.setDirectory(session, directory.absolutePath)
        }
        check(directory.canonicalFile == directory.absoluteFile)
        val file = File(directory, fileName(index))
        if (!file.createNewFile()) throw IOException("Cannot create filler file")
        FillerFile(Uri.fromFile(file).toString())
    }

    override suspend fun append(file: FillerFile, count: Int) = withContext(Dispatchers.IO) {
        val path = Uri.parse(file.id).path ?: throw IOException("Invalid filler file")
        FileOutputStream(File(path), true).use { it.write(Random.nextBytes(count)) }
    }

    override suspend fun cleanup(session: FillerSession): Boolean = withContext(Dispatchers.IO) {
        if (!validate(session.target)) return@withContext false
        try {
            val parent = root() ?: return@withContext false
            val directory = sessionDirectory(parent, session)
            val entry = journal.entry(session)
            if (entry.directory != null && entry.directory != directory.absolutePath) return@withContext false
            if (directory.exists() && directory.canonicalFile != directory.absoluteFile) return@withContext false
            val filesGone = deleteRecordedFiles(session, entry, directory)
            val pendingGone = deletePendingFile(session, entry, directory)
            if (!filesGone || !pendingGone) return@withContext false
            if (directory.exists()) {
                val children = directory.list() ?: return@withContext false
                if (children.isNotEmpty() || !directory.delete()) return@withContext false
            }
            if (entry.directory != null) journal.setDirectory(session, null)
            true
        } catch (_: IOException) {
            false
        } catch (_: SecurityException) {
            false
        } catch (_: IllegalArgumentException) {
            false
        }
    }

    /** The precommitted create of a dead run: an abandoned empty file, or nothing to lose (S0049). */
    override suspend fun discardPendingCreate(session: FillerSession): Boolean = withContext(Dispatchers.IO) {
        if (!validate(session.target)) return@withContext false
        try {
            val parent = root() ?: return@withContext false
            val directory = sessionDirectory(parent, session)
            val entry = journal.entry(session)
            if (entry.directory != null && entry.directory != directory.absolutePath) return@withContext false
            if (directory.exists() && directory.canonicalFile != directory.absoluteFile) return@withContext false
            deletePendingFile(session, entry, directory)
        } catch (_: IOException) {
            false
        } catch (_: SecurityException) {
            false
        } catch (_: IllegalArgumentException) {
            false
        }
    }

    private suspend fun deleteRecordedFiles(
        session: FillerSession,
        entry: FillerJournalEntry,
        directory: File,
    ): Boolean {
        var complete = true
        for (id in entry.files) {
            val uri = Uri.parse(id)
            val file = uri.path?.let(::File)
            val owned = uri.scheme == "file" && file != null && isOwnedFile(file, directory)
            val removed = owned && file != null && (!file.exists() || file.delete())
            if (owned && removed) {
                journal.forgetFile(session, id)
            } else {
                complete = false
            }
        }
        return complete
    }

    private suspend fun deletePendingFile(
        session: FillerSession,
        entry: FillerJournalEntry,
        directory: File,
    ): Boolean {
        val index = entry.pendingIndex
        if (index == null) return true
        val file = File(directory, fileName(index))
        val removed = file.canonicalFile == file.absoluteFile && (!file.exists() || file.delete())
        if (removed) journal.clearPending(session)
        return removed
    }

    private fun isOwnedFile(file: File, directory: File): Boolean =
        file.parentFile == directory && file.name.matches(FILE_NAME) && file.canonicalFile == file.absoluteFile

    private fun root(): File? = try {
        context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)?.canonicalFile
    } catch (_: IOException) {
        null
    } catch (_: SecurityException) {
        null
    }

    private fun target() = FillerTarget(LOCATION, PRIMARY_VOLUME_ID)

    private fun sessionDirectory(parent: File, session: FillerSession): File {
        require(UUID.fromString(session.id).toString() == session.id)
        return File(parent, ".filler-${session.id}")
    }

    private fun fileName(index: Int) = "fill-$index.bin"

    private companion object {
        const val LOCATION = "filler://app-downloads"

        /** The platform's name of built-in storage, the phone's StorageVolumeInfo.PRIMARY_VOLUME_ID. */
        const val PRIMARY_VOLUME_ID = "primary"
        val FILE_NAME = Regex("fill-[0-9]+\\.bin")
    }
}

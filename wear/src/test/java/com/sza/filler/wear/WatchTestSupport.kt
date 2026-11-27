package com.sza.filler.wear

import android.content.ComponentName
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.robolectric.shadows.ShadowStatFs
import java.io.File

// Shared by the watch tests (S0029). The phone's tests use runTest and setMain; the watch adapter and controller hop
// to Dispatchers.IO themselves, which a test dispatcher cannot replace, so a test here waits on real threads.

private const val WATCH_TEST_TIMEOUT_MILLIS = 30_000L

/** Runs a test body on real threads; a hang fails the test after 30 seconds instead of stalling the preflight. */
fun runWatchTest(body: suspend CoroutineScope.() -> Unit) = runBlocking {
    withTimeout(WATCH_TEST_TIMEOUT_MILLIS) { body() }
}

/** Makes Robolectric's StatFs report [bytes] free for [directory], in whole blocks of the shadow's block size. */
fun registerFreeBytes(directory: File, bytes: Long) {
    val blocks = (bytes / ShadowStatFs.BLOCK_SIZE).toInt()
    ShadowStatFs.registerStats(directory, blocks, blocks, blocks)
}

/**
 * The id of [file] in the one form the adapter's own `Uri.parse(id).path` reads back on any host. The adapter writes
 * `Uri.fromFile(file).toString()`, which is right on Android; Robolectric runs the framework's real `Uri`, and on a
 * Windows host a drive-letter path (`C:\..`) is not absolute there, so that id reads back as an empty path. The tests
 * record this id for a file the adapter created, so the adapter's append and cleanup are exercised the same way on
 * every host. On Linux and macOS it equals `Uri.fromFile(file).toString()`.
 */
fun fileId(file: File): String = "file:///" + file.absolutePath.replace('\\', '/').trimStart('/')

/** A watch whose app-owned external directory cannot be resolved: the adapter then has no place at all. */
class NoExternalDirectoryContext(base: Context) : ContextWrapper(base) {
    override fun getExternalFilesDir(type: String?): File? = null
}

/** Stands in for the platform that starts the foreground host of a run: records the request, or refuses it. */
class RecordingHostContext(base: Context) : ContextWrapper(base) {
    val startedServices = mutableListOf<Intent>()
    var refuse = false

    override fun startForegroundService(service: Intent): ComponentName? {
        // ForegroundServiceStartNotAllowedException is an IllegalStateException, which the controller catches.
        if (refuse) throw IllegalStateException("The platform refused the foreground host")
        startedServices += service
        return service.component
    }
}

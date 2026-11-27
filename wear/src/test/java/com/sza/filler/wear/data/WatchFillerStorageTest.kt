package com.sza.filler.wear.data

import android.net.Uri
import android.os.Environment
import com.sza.filler.data.filler.FillerSessionJournal
import com.sza.filler.domain.filler.FillerFile
import com.sza.filler.domain.filler.FillerSession
import com.sza.filler.domain.filler.FillerTarget
import com.sza.filler.wear.NoExternalDirectoryContext
import com.sza.filler.wear.R
import com.sza.filler.wear.fileId
import com.sza.filler.wear.registerFreeBytes
import com.sza.filler.wear.runWatchTest
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.job
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowEnvironment
import java.io.File
import java.io.IOException

// The watch storage adapter (S0029). Its phone counterpart is AppFillerStorageTest, ported from FastMediaSorter
// release 48 (S4521); the interrupted-create case below is that test's, on the watch adapter. Deliberate differences:
// - a test body runs in runWatchTest (real threads, a timeout) instead of runTest, see WatchTestSupport.kt;
// - a file the adapter created is recorded and appended to by an id that fileId() rebuilds, because the framework's
//   Uri reads the adapter's own id back as an empty path on a Windows host (see fileId); the adapter's create is still
//   called, and the file it makes is looked up on disk, not through its id;
// - the cases that only exist on the watch: grant always refuses, one location, no external directory.
// The location, the session directory prefix and the file names are the phone's, unchanged.

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class WatchFillerStorageTest {
    private val context = RuntimeEnvironment.getApplication()
    private val journalScope = CoroutineScope(Dispatchers.Unconfined)
    private lateinit var downloads: File
    private lateinit var journal: FillerSessionJournal
    private lateinit var storage: WatchFillerStorage

    @Before
    fun setUp() {
        File(context.noBackupFilesDir, "filler-sessions.json").delete()
        File(context.noBackupFilesDir, "filler-sessions.json.bak").delete()
        File(context.noBackupFilesDir, "filler-sessions.json.new").delete()
        // Robolectric reports no state for a directory nobody declared, so the volume a watch would report as
        // mounted is declared here; the adapter asks about the canonical path.
        downloads = requireNotNull(context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)).canonicalFile
        ShadowEnvironment.setExternalStorageState(downloads, Environment.MEDIA_MOUNTED)
        journal = FillerSessionJournal(context, journalScope)
        storage = WatchFillerStorage(context, journal)
    }

    @After
    fun tearDown() = runBlocking { journalScope.coroutineContext.job.cancelAndJoin() }

    @Test
    fun `the default location is the app-owned downloads place and needs no grant`() = runWatchTest {
        assertEquals(LOCATION, storage.defaultLocation())
        val place = requireNotNull(storage.place(LOCATION))
        assertEquals(FillerTarget(LOCATION, "primary"), place.target)
        assertEquals(context.getString(R.string.filler_watch_storage), place.volumeName)
        assertEquals(downloads.absolutePath, place.folderName)
        assertTrue(storage.validate(place.target))
    }

    @Test
    fun `a grant is always refused because the watch has no folder picker`() = runWatchTest {
        assertFalse(storage.grant(LOCATION))
        assertFalse(storage.grant("content://com.android.externalstorage.documents/tree/primary%3AMusic"))
    }

    @Test
    fun `no other location has a place`() = runWatchTest {
        assertNull(storage.place("filler://other"))
        assertNull(storage.place("content://com.android.externalstorage.documents/tree/primary%3AMusic"))
    }

    @Test
    fun `a target the adapter does not own is not valid`() = runWatchTest {
        val own = target()
        assertTrue(storage.validate(own))
        assertFalse(storage.validate(FillerTarget("filler://other", own.volumeId)))
        assertFalse(storage.validate(FillerTarget(own.location, "1234-ABCD")))
    }

    @Test
    fun `an unmounted volume is not valid and measures null`() = runWatchTest {
        val own = target()
        ShadowEnvironment.setExternalStorageState(downloads, Environment.MEDIA_UNMOUNTED)

        assertFalse(storage.validate(own))
        assertNull(storage.availableBytes(own))
    }

    @Test
    fun `the free bytes are the ones the volume reports`() = runWatchTest {
        registerFreeBytes(downloads, 500L shl 20)

        assertEquals(500L shl 20, storage.availableBytes(target()))
    }

    @Test
    fun `without an app-owned external directory there is no default location and no place`() = runWatchTest {
        val bare = WatchFillerStorage(NoExternalDirectoryContext(context), journal)
        val own = FillerTarget(LOCATION, "primary")

        assertNull(bare.defaultLocation())
        assertNull(bare.place(LOCATION))
        assertFalse(bare.validate(own))
        assertNull(bare.availableBytes(own))
    }

    @Test
    fun `the session directory and the file names are the phone's`() = runWatchTest {
        val session = journal.begin(target())
        journal.prepareCreate(session, 0)
        val created = storage.create(session, 0)
        journal.recordCreated(session, 0, created)
        newFile(session, 1)

        val directory = sessionDirectory(session)
        assertEquals("file", Uri.parse(created.id).scheme)
        assertEquals(File(downloads, ".filler-${session.id}"), directory)
        assertEquals(listOf("fill-0.bin", "fill-1.bin"), requireNotNull(directory.list()).sorted())
    }

    @Test
    fun `a file that exists is never overwritten by a create`() = runWatchTest {
        val session = journal.begin(target())
        newFile(session, 0)

        val failure = runCatching { storage.create(session, 0) }.exceptionOrNull()

        assertTrue(failure is IOException)
    }

    @Test
    fun `a session id that is not a uuid reaches no directory`() = runWatchTest {
        val stranger = FillerSession("../escape", target())

        assertTrue(runCatching { storage.create(stranger, 0) }.exceptionOrNull() is IllegalArgumentException)
        assertFalse(storage.cleanup(stranger))
        assertFalse(File(downloads.parentFile, "escape").exists())
    }

    @Test
    fun `interrupted create is cleaned and unrelated file is preserved`() = runWatchTest {
        val session = journal.begin(target())
        journal.prepareCreate(session, 0)
        storage.create(session, 0)
        val directory = sessionDirectory(session)
        val created = File(directory, "fill-0.bin")
        storage.append(FillerFile(fileId(created)), 8)
        assertEquals(8L, created.length())
        val foreign = File(directory, "user-file.txt")
        foreign.writeText("keep")

        assertFalse(storage.cleanup(session))
        assertTrue(foreign.exists())
        assertFalse(created.exists())
        assertNull(journal.entry(session).pendingIndex)

        foreign.delete()
        assertTrue(storage.cleanup(session))
        assertFalse(directory.exists())
        journal.finish(session)
        assertTrue(journal.pendingSessions().isEmpty())
    }

    @Test
    fun `cleanup deletes the recorded files and the directory and leaves a file beside it`() = runWatchTest {
        val session = journal.begin(target())
        val first = newFile(session, 0)
        val second = newFile(session, 1)
        storage.append(first, 16)
        storage.append(second, 16)
        val directory = sessionDirectory(session)
        val userFile = File(downloads, "holiday.jpg")
        userFile.writeText("keep")

        assertTrue(storage.cleanup(session))

        assertFalse(directory.exists())
        assertTrue(userFile.exists())
        assertTrue(journal.entry(session).files.isEmpty())
        assertNull(journal.entry(session).directory)
    }

    @Test
    fun `a foreign file in the session directory survives and keeps the directory`() = runWatchTest {
        val session = journal.begin(target())
        newFile(session, 0)
        val directory = sessionDirectory(session)
        val foreign = File(directory, "notes.txt")
        foreign.writeText("keep")

        assertFalse(storage.cleanup(session))

        assertTrue(foreign.exists())
        assertTrue(directory.exists())
        assertFalse(File(directory, "fill-0.bin").exists())
        assertTrue(journal.entry(session).files.isEmpty())
    }

    @Test
    fun `a recorded file outside the session directory is never deleted`() = runWatchTest {
        val session = journal.begin(target())
        val outside = File(downloads, "fill-0.bin")
        outside.writeText("user data")
        journal.prepareCreate(session, 0)
        journal.recordCreated(session, 0, FillerFile(fileId(outside)))

        assertFalse(storage.cleanup(session))

        assertTrue(outside.exists())
        assertEquals(listOf(fileId(outside)), journal.entry(session).files)
    }

    @Test
    fun `a recorded file whose name is not a filler name is never deleted`() = runWatchTest {
        val session = journal.begin(target())
        newFile(session, 0)
        val directory = sessionDirectory(session)
        val misnamed = File(directory, "notes.txt")
        misnamed.writeText("keep")
        journal.prepareCreate(session, 1)
        journal.recordCreated(session, 1, FillerFile(fileId(misnamed)))

        assertFalse(storage.cleanup(session))

        assertTrue(misnamed.exists())
        assertFalse(File(directory, "fill-0.bin").exists())
    }

    @Test
    fun `a journal directory that is not the session's is refused and nothing is deleted`() = runWatchTest {
        val session = journal.begin(target())
        newFile(session, 0)
        val directory = sessionDirectory(session)
        journal.setDirectory(session, File(downloads, ".filler-other").absolutePath)

        assertFalse(storage.cleanup(session))

        assertTrue(File(directory, "fill-0.bin").exists())
    }

    @Test
    fun `cleanup waits while the volume is not valid and succeeds when it is back`() = runWatchTest {
        val session = journal.begin(target())
        newFile(session, 0)
        val directory = sessionDirectory(session)
        ShadowEnvironment.setExternalStorageState(downloads, Environment.MEDIA_UNMOUNTED)

        assertFalse(storage.cleanup(session))
        assertTrue(File(directory, "fill-0.bin").exists())

        ShadowEnvironment.setExternalStorageState(downloads, Environment.MEDIA_MOUNTED)
        assertTrue(storage.cleanup(session))
        assertFalse(directory.exists())
    }

    private suspend fun target(): FillerTarget = requireNotNull(storage.place(LOCATION)).target

    private suspend fun sessionDirectory(session: FillerSession): File =
        File(requireNotNull(journal.entry(session).directory))

    /** Creates file [index] through the adapter and records it as the engine does, by the id fileId() rebuilds. */
    private suspend fun newFile(session: FillerSession, index: Int): FillerFile {
        journal.prepareCreate(session, index)
        storage.create(session, index)
        val file = FillerFile(fileId(File(sessionDirectory(session), "fill-$index.bin")))
        journal.recordCreated(session, index, file)
        return file
    }

    private companion object {
        /** The adapter's own constant is private; the phone's value, unchanged on the watch. */
        const val LOCATION = "filler://app-downloads"
    }
}

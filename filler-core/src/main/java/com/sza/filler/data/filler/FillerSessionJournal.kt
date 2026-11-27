package com.sza.filler.data.filler

import android.content.Context
import android.util.Log
import com.sza.filler.domain.filler.FillerFile
import com.sza.filler.domain.filler.FillerJournal
import com.sza.filler.domain.filler.FillerPendingCleanup
import com.sza.filler.domain.filler.FillerSession
import com.sza.filler.domain.filler.FillerTarget
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject
import java.io.File
import java.io.FileNotFoundException
import java.io.IOException
import java.util.UUID

// Ported from FastMediaSorter release 48 (data/filler/FillerSessionJournal.kt, S4521). Deliberate differences:
// - no Hilt: the surface creates exactly one instance per process with the application context and an
//   application-lifetime scope (the source's @Singleton, @ApplicationContext and @ApplicationScope);
// - the entry type and the adapter-facing members are public instead of internal, because the storage
//   adapters live in each surface module, not in this one;
// - android.util.Log instead of Timber, which this app does not carry;
// - resumeIndex, the file index a resumed run writes next (owner decision of 2026-11-16, S0049): the source has
//   none, and a pending create was discarded before it is asked, so the count recorded so far is the next index;
// - AtomicStoreFile (java.nio.file.Files.move with REPLACE_EXISTING) in place of android.util.AtomicFile: keeps the
//   same .new/.bak recovery protocol while allowing overwrites on Windows Robolectric hosts as well as Android.
// The file name and the JSON shape are the source's, unchanged.

data class FillerJournalEntry(
    val session: FillerSession,
    val directory: String? = null,
    val pendingIndex: Int? = null,
    val files: List<String> = emptyList(),
)

/** Keeps incomplete sessions outside the selected volume so an ejected card can be recovered. */
class FillerSessionJournal(
    context: Context,
    scope: CoroutineScope,
) : FillerJournal, FillerPendingCleanup {
    // noBackupFilesDir checks the directory on disk; resolving it lazily keeps that read inside read/change on IO.
    private val file by lazy { AtomicStoreFile(File(context.noBackupFilesDir, JOURNAL_FILE)) }
    private val mutex = Mutex()
    private val pending = MutableStateFlow(false)
    override val hasPending: StateFlow<Boolean> = pending.asStateFlow()

    init {
        scope.launch(Dispatchers.IO) {
            mutex.withLock {
                pending.value = try {
                    load().isNotEmpty()
                } catch (e: JSONException) {
                    unreadable(e)
                } catch (e: IOException) {
                    unreadable(e)
                }
            }
        }
    }

    override suspend fun pendingSessions(): List<FillerSession> = read { entries -> entries.map { it.session } }

    override suspend fun begin(target: FillerTarget): FillerSession = change { entries ->
        check(entries.isEmpty())
        val session = FillerSession(UUID.randomUUID().toString(), target)
        entries.add(FillerJournalEntry(session))
        session
    }

    override suspend fun prepareCreate(session: FillerSession, index: Int) = change { entries ->
        entries.update(session) { entry ->
            check(entry.pendingIndex == null)
            entry.copy(pendingIndex = index)
        }
    }

    override suspend fun recordCreated(session: FillerSession, index: Int, file: FillerFile) = change { entries ->
        entries.update(session) { entry ->
            check(entry.pendingIndex == index)
            check(file.id !in entry.files)
            entry.copy(pendingIndex = null, files = entry.files + file.id)
        }
    }

    override suspend fun finish(session: FillerSession) = change { entries ->
        val entry = entries.single { it.session == session }
        check(entry.pendingIndex == null && entry.files.isEmpty() && entry.directory == null)
        entries.remove(entry)
        Unit
    }

    /** A resumed run writes past every recorded file (S0049); the files of a session are created in order. */
    override suspend fun resumeIndex(session: FillerSession): Int = read { entries ->
        entries.single { it.session == session }.files.size
    }

    suspend fun entry(session: FillerSession): FillerJournalEntry = read { entries ->
        entries.single { it.session == session }
    }

    suspend fun setDirectory(session: FillerSession, directory: String?) = change { entries ->
        entries.update(session) { it.copy(directory = directory) }
    }

    suspend fun clearPending(session: FillerSession) = change { entries ->
        entries.update(session) { it.copy(pendingIndex = null) }
    }

    suspend fun forgetFile(session: FillerSession, fileId: String) = change { entries ->
        entries.update(session) { entry -> entry.copy(files = entry.files - fileId) }
    }

    private suspend fun <T> read(block: (List<FillerJournalEntry>) -> T): T = withContext(Dispatchers.IO) {
        mutex.withLock { block(load()) }
    }

    private suspend fun <T> change(block: (MutableList<FillerJournalEntry>) -> T): T = withContext(Dispatchers.IO) {
        mutex.withLock {
            val entries = load().toMutableList()
            val result = block(entries)
            save(entries)
            pending.value = entries.isNotEmpty()
            result
        }
    }

    private fun load(): List<FillerJournalEntry> {
        val bytes = try {
            file.readBytes()
        } catch (_: FileNotFoundException) {
            return emptyList()
        }
        val json = JSONArray(bytes.toString(Charsets.UTF_8))
        return List(json.length()) { index -> decode(json.getJSONObject(index)) }
    }

    private fun decode(json: JSONObject): FillerJournalEntry {
        val session = FillerSession(
            id = json.getString("id"),
            target = FillerTarget(json.getString("location"), json.getString("volume")),
        )
        val files = json.getJSONArray("files")
        return FillerJournalEntry(
            session = session,
            directory = if (json.isNull("directory")) null else json.getString("directory"),
            pendingIndex = if (json.isNull("pending")) null else json.getInt("pending"),
            files = List(files.length()) { files.getString(it) },
        )
    }

    private fun save(entries: List<FillerJournalEntry>) {
        val array = JSONArray()
        entries.forEach { entry ->
            array.put(
                JSONObject()
                    .put("id", entry.session.id)
                    .put("location", entry.session.target.location)
                    .put("volume", entry.session.target.volumeId)
                    .put("directory", entry.directory ?: JSONObject.NULL)
                    .put("pending", entry.pendingIndex ?: JSONObject.NULL)
                    .put("files", JSONArray(entry.files)),
            )
        }
        file.writeBytes(array.toString().toByteArray(Charsets.UTF_8))
    }

    // The file is left untouched and the program stays reachable, because the unread journal may list files
    // that still wait for deletion.
    private fun unreadable(error: Exception): Boolean {
        Log.w(LOG_TAG, "Filler journal could not be read; keeping cleanup reachable", error)
        return true
    }

    private fun MutableList<FillerJournalEntry>.update(
        session: FillerSession,
        transform: (FillerJournalEntry) -> FillerJournalEntry,
    ) {
        val index = indexOfFirst { it.session == session }
        check(index >= 0)
        this[index] = transform(this[index])
    }

    private companion object {
        const val JOURNAL_FILE = "filler-sessions.json"
        const val LOG_TAG = "FillerJournal"
    }
}

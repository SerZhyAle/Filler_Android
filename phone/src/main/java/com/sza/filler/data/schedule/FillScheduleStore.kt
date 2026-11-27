package com.sza.filler.data.schedule

import android.content.Context
import android.util.Log
import com.sza.filler.data.filler.AtomicStoreFile
import com.sza.filler.domain.filler.ScheduledFillOutcome
import com.sza.filler.domain.filler.ScheduledFillReason
import com.sza.filler.domain.filler.UnattendedFillDays
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

// This product's own (S0025), written after the pattern of the ported FillerSessionJournal: one app-private JSON
// file in noBackupFilesDir behind an AtomicFile and a mutex, read from disk on every access so the worker of a cold
// process sees what the screen saved. Deliberate difference from FastMediaSorter, which keeps schedules and their
// history in its Room database: this app carries no database, and a schedule list of a few rows and a bounded
// history need none. No other product reads this file (S0025 section 1: no shared-contract boundary).

/** Everything the schedule screen shows: the schedules in saving order, the history, newest first, and the global pause flag. */
data class FillScheduleData(
    val schedules: List<FillSchedule> = emptyList(),
    val history: List<FillHistoryEntry> = emptyList(),
    val lastFillDay: Long? = null,
    val paused: Boolean = false,
)

class FillScheduleStore(
    context: Context,
    scope: CoroutineScope,
) : UnattendedFillDays {
    private val file by lazy { AtomicStoreFile(File(context.noBackupFilesDir, STORE_FILE)) }
    private val mutex = Mutex()
    private val current = MutableStateFlow(FillScheduleData())
    val data: StateFlow<FillScheduleData> = current.asStateFlow()

    init {
        scope.launch(Dispatchers.IO) { mutex.withLock { current.value = loadOrEmpty() } }
    }

    suspend fun schedules(): List<FillSchedule> = read { it.schedules }

    suspend fun schedule(id: String): FillSchedule? = read { data -> data.schedules.firstOrNull { it.id == id } }

    /** Adds [schedule] or replaces the one with its id. */
    suspend fun save(schedule: FillSchedule) = change { data ->
        val others = data.schedules.filterNot { it.id == schedule.id }
        val index = data.schedules.indexOfFirst { it.id == schedule.id }
        val schedules = if (index < 0) others + schedule else others.toMutableList().apply { add(index, schedule) }
        data.copy(schedules = schedules)
    }

    /** Removes the schedule; its history stays, so what it did remains readable. */
    suspend fun delete(id: String) = change { data -> data.copy(schedules = data.schedules.filterNot { it.id == id }) }

    suspend fun addHistory(entry: FillHistoryEntry) = change { data ->
        data.copy(history = (listOf(entry) + data.history).take(HISTORY_LIMIT))
    }

    suspend fun clearHistory() = change { data -> data.copy(history = emptyList()) }

    suspend fun isPaused(): Boolean = read { it.paused }

    suspend fun setPaused(paused: Boolean) = change { data -> data.copy(paused = paused) }

    override suspend fun lastFillDay(): Long? = read { it.lastFillDay }

    override suspend fun setLastFillDay(day: Long?) = change { it.copy(lastFillDay = day) }

    private suspend fun <T> read(block: (FillScheduleData) -> T): T = withContext(Dispatchers.IO) {
        mutex.withLock { block(loadOrEmpty()) }
    }

    private suspend fun change(block: (FillScheduleData) -> FillScheduleData) = withContext(Dispatchers.IO) {
        mutex.withLock {
            val next = block(loadOrEmpty())
            save(next)
            current.value = next
        }
    }

    // An unreadable file is logged and read as empty: the next save rewrites it. A schedule lost this way stops
    // running, which is the safe direction for a feature that writes to storage unattended.
    private fun loadOrEmpty(): FillScheduleData = try {
        load()
    } catch (e: JSONException) {
        Log.w(LOG_TAG, "Schedule store could not be read", e)
        FillScheduleData()
    } catch (e: IOException) {
        Log.w(LOG_TAG, "Schedule store could not be read", e)
        FillScheduleData()
    }

    private fun load(): FillScheduleData {
        val bytes = try {
            file.readBytes()
        } catch (_: FileNotFoundException) {
            return FillScheduleData()
        }
        val json = JSONObject(bytes.toString(Charsets.UTF_8))
        val schedules = json.optJSONArray("schedules") ?: JSONArray()
        val history = json.optJSONArray("history") ?: JSONArray()
        return FillScheduleData(
            schedules = List(schedules.length()) { decodeSchedule(schedules.getJSONObject(it)) },
            history = List(history.length()) { decodeEntry(history.getJSONObject(it)) },
            lastFillDay = if (json.isNull("lastFillDay")) null else json.getLong("lastFillDay"),
            paused = json.optBoolean("paused", false),
        )
    }

    private fun decodeSchedule(json: JSONObject) = FillSchedule(
        id = json.getString("id"),
        location = json.getString("location"),
        folderName = json.getString("folder"),
        volumeName = json.getString("volume"),
        minuteOfDay = json.getInt("minute"),
        intervalDays = json.getInt("interval"),
        firstDay = json.getLong("firstDay"),
        enabled = json.getBoolean("enabled"),
        revision = json.getLong("revision"),
    )

    private fun decodeEntry(json: JSONObject) = FillHistoryEntry(
        scheduleId = json.getString("schedule"),
        folderName = json.getString("folder"),
        volumeName = json.getString("volume"),
        dueAt = json.getLong("due"),
        startedAt = json.getLong("started"),
        outcome = ScheduledFillOutcome.entries.firstOrNull { it.name == json.getString("outcome") }
            ?: ScheduledFillOutcome.ERROR,
        reason = ScheduledFillReason.fromName(if (json.isNull("reason")) null else json.getString("reason")),
        writtenBytes = json.getLong("written"),
    )

    private fun save(data: FillScheduleData) {
        val schedules = JSONArray()
        data.schedules.forEach { schedule ->
            schedules.put(
                JSONObject()
                    .put("id", schedule.id)
                    .put("location", schedule.location)
                    .put("folder", schedule.folderName)
                    .put("volume", schedule.volumeName)
                    .put("minute", schedule.minuteOfDay)
                    .put("interval", schedule.intervalDays)
                    .put("firstDay", schedule.firstDay)
                    .put("enabled", schedule.enabled)
                    .put("revision", schedule.revision),
            )
        }
        val history = JSONArray()
        data.history.forEach { entry ->
            history.put(
                JSONObject()
                    .put("schedule", entry.scheduleId)
                    .put("folder", entry.folderName)
                    .put("volume", entry.volumeName)
                    .put("due", entry.dueAt)
                    .put("started", entry.startedAt)
                    .put("outcome", entry.outcome.name)
                    .put("reason", entry.reason?.name ?: JSONObject.NULL)
                    .put("written", entry.writtenBytes),
            )
        }
        val json = JSONObject()
            .put("schedules", schedules)
            .put("history", history)
            .put("lastFillDay", data.lastFillDay ?: JSONObject.NULL)
            .put("paused", data.paused)
        file.writeBytes(json.toString().toByteArray(Charsets.UTF_8))
    }

    private companion object {
        const val STORE_FILE = "fill-schedules.json"
        const val LOG_TAG = "FillScheduleStore"

        /** The history keeps the newest attempts only; at one fill a day this is more than three months. */
        const val HISTORY_LIMIT = 100
    }
}

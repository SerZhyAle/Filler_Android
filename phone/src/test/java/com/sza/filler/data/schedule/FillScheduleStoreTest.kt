package com.sza.filler.data.schedule

import com.sza.filler.domain.filler.ScheduledFillOutcome
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.io.File

// Robolectric tests for FillScheduleStore extensions added by FILLER-0067 (global pause flag,
// Clear history, and backward-compatible load of pre-FILLER-0067 JSON files without "paused").
@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class FillScheduleStoreTest {

    @Test
    fun `setPaused and clearHistory persist across store reads`() = runTest {
        val context = RuntimeEnvironment.getApplication()
        val storeFile = File(context.noBackupFilesDir, "fill-schedules.json")
        storeFile.delete()
        val store = FillScheduleStore(context, TestScope(testScheduler))

        assertFalse(store.isPaused())
        store.setPaused(true)
        assertTrue(store.isPaused())

        store.addHistory(
            FillHistoryEntry(
                scheduleId = "s1",
                folderName = "Downloads",
                volumeName = "Internal storage",
                dueAt = 1_000L,
                startedAt = 1_000L,
                outcome = ScheduledFillOutcome.OK,
                reason = null,
                writtenBytes = 4_096L,
            ),
        )
        assertEquals(1, store.data.value.history.size)

        store.clearHistory()
        assertTrue(store.data.value.history.isEmpty())
        assertTrue(store.isPaused())
    }

    @Test
    fun `legacy JSON without paused field defaults to false`() = runTest {
        val context = RuntimeEnvironment.getApplication()
        val storeFile = File(context.noBackupFilesDir, "fill-schedules.json")
        storeFile.parentFile?.mkdirs()
        storeFile.writeText("""{"schedules":[],"history":[],"lastFillDay":null}""")

        val store = FillScheduleStore(context, TestScope(testScheduler))
        assertFalse(store.isPaused())
    }
}

package com.sza.filler.domain.filler

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

// The daily cap of unattended fills (S0025 criterion 6, owner decision 2026-11-13): a real FillerEngine over fakes,
// as in RunScheduledFillUseCaseTest, so "writes nothing" is measured at the storage, not assumed.
class CappedScheduledFillTest {
    private val target = FillerTarget(TREE, "1234-5678")
    private val journal = FakeJournal()
    private val storage = FakeStorage()
    private val days = FakeDays()
    private val engine = FillerEngine(storage, journal)
    private val capped = CappedScheduledFill(
        RunScheduledFillUseCase(engine, FakeResolver(FillerPlace(target, "SD card", "Card")), storage),
        days,
    )

    @Test
    fun `a second unattended fill on the same day is refused and writes nothing`() = runTest {
        assertEquals(ScheduledFillOutcome.OK, capped(TREE, NAME, DAY).outcome)
        val appendsAfterFirst = storage.appends
        journal.began = false
        storage.available = INITIAL_SPACE

        val second = capped(TREE, NAME, DAY)

        assertEquals(ScheduledFillOutcome.SKIPPED, second.outcome)
        assertEquals(ScheduledFillReason.FILL_DAILY_CAP, second.reason)
        assertEquals(0L, second.writtenBytes)
        assertEquals(appendsAfterFirst, storage.appends)
        assertFalse(journal.began)
    }

    @Test
    fun `the next day admits a fill again`() = runTest {
        capped(TREE, NAME, DAY)
        storage.available = INITIAL_SPACE

        assertEquals(ScheduledFillOutcome.OK, capped(TREE, NAME, DAY + 1).outcome)
        assertEquals(DAY + 1, days.last)
    }

    @Test
    fun `a refusal before any write does not use up the day`() = runTest {
        days.last = DAY - 1
        storage.available = FILLER_RESERVE_BYTES

        val refused = capped(TREE, NAME, DAY)

        assertEquals(ScheduledFillReason.FILL_NO_FREE_SPACE, refused.reason)
        assertEquals(DAY - 1, days.last)
        storage.available = INITIAL_SPACE
        assertEquals(ScheduledFillOutcome.OK, capped(TREE, NAME, DAY).outcome)
    }

    @Test
    fun `a run that began writing uses up the day even when it failed`() = runTest {
        storage.writeFails = true

        val failed = capped(TREE, NAME, DAY)

        assertEquals(ScheduledFillReason.FILL_WRITE_FAILED, failed.reason)
        assertTrue(failed.sessionStarted)
        assertEquals(DAY, days.last)
        storage.writeFails = false
        assertEquals(ScheduledFillReason.FILL_DAILY_CAP, capped(TREE, NAME, DAY).reason)
    }

    @Test
    fun `a fresh install has no day recorded and runs`() = runTest {
        assertNull(days.last)

        assertEquals(ScheduledFillOutcome.OK, capped(TREE, NAME, DAY).outcome)
    }

    private class FakeDays : UnattendedFillDays {
        var last: Long? = null
        override suspend fun lastFillDay(): Long? = last
        override suspend fun setLastFillDay(day: Long?) {
            last = day
        }
    }

    private class FakeResolver(private val place: FillerPlace) : FillerTargetResolver {
        override suspend fun grant(location: String): Boolean = true
        override suspend fun place(location: String): FillerPlace = place
    }

    private class FakeJournal : FillerJournal {
        var pending: FillerSession? = null
        var began = false

        override suspend fun pendingSessions(): List<FillerSession> = listOfNotNull(pending)

        override suspend fun begin(target: FillerTarget): FillerSession {
            began = true
            return FillerSession("session", target).also { pending = it }
        }

        override suspend fun prepareCreate(session: FillerSession, index: Int) = Unit
        override suspend fun recordCreated(session: FillerSession, index: Int, file: FillerFile) = Unit

        override suspend fun finish(session: FillerSession) {
            pending = null
        }

        override suspend fun resumeIndex(session: FillerSession): Int = 0
    }

    private class FakeStorage : FillerStorage {
        var available = INITIAL_SPACE
        var writeFails = false
        var appends = 0

        override suspend fun validate(target: FillerTarget): Boolean = true
        override suspend fun availableBytes(target: FillerTarget): Long = available
        override suspend fun create(session: FillerSession, index: Int): FillerFile = FillerFile("created-$index")

        override suspend fun append(file: FillerFile, count: Int) {
            check(!writeFails)
            appends++
            available -= count
        }

        override suspend fun cleanup(session: FillerSession): Boolean = true
        override suspend fun discardPendingCreate(session: FillerSession): Boolean = true
    }

    private companion object {
        const val TREE = "content://com.android.externalstorage.documents/tree/1234-5678%3ACard"
        const val NAME = "Card"
        const val DAY = 20_000L
        const val INITIAL_SPACE = 2 * FILLER_RESERVE_BYTES
    }
}

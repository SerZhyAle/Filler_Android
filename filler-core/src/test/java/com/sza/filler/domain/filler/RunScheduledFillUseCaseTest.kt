package com.sza.filler.domain.filler

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.async
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

// Ported from FastMediaSorter release 48 (RunScheduledFillUseCaseTest.kt, S4522; S0025 here). Deliberate
// difference: the source mocks the engine with MockK, which this product does not carry; here a real FillerEngine
// runs over fakes, so each verdict is produced by the engine itself rather than stubbed. The cases are the source's.
@OptIn(ExperimentalCoroutinesApi::class)
class RunScheduledFillUseCaseTest {
    private val target = FillerTarget(TREE, "1234-5678")
    private val place = FillerPlace(target, "SD card", "Card")
    private val journal = FakeJournal()
    private val storage = FakeStorage()
    private val resolver = FakeResolver(place)
    private val engine = FillerEngine(storage, journal)
    private val useCase = RunScheduledFillUseCase(engine, resolver, storage)

    @Test
    fun `a finished and cleaned fill is a success`() = runTest {
        val result = useCase(TREE, NAME)

        assertEquals(ScheduledFillOutcome.OK, result.outcome)
        assertNull(result.reason)
        assertEquals(INITIAL_SPACE - FILLER_RESERVE_BYTES, result.writtenBytes)
    }

    @Test
    fun `the scheduled run keeps the default reserve`() = runTest {
        useCase(TREE, NAME)

        assertEquals(FILLER_RESERVE_BYTES, storage.lowest)
    }

    @Test
    fun `a fill whose cleanup did not finish is never a success`() = runTest {
        storage.cleanupSucceeds = false
        val finished = useCase(TREE, NAME)
        journal.pending = null
        storage.available = INITIAL_SPACE
        storage.writeFails = true
        val failed = useCase(TREE, NAME)

        assertEquals(ScheduledFillOutcome.ERROR, finished.outcome)
        assertEquals(ScheduledFillReason.FILL_CLEANUP_PENDING, finished.reason)
        assertEquals(ScheduledFillReason.FILL_CLEANUP_PENDING, failed.reason)
    }

    @Test
    fun `each refusal maps to its own reason`() = runTest {
        storage.available = FILLER_RESERVE_BYTES
        val noSpace = useCase(TREE, NAME)
        assertEquals(ScheduledFillReason.FILL_NO_FREE_SPACE, noSpace.reason)
        assertEquals(ScheduledFillOutcome.SKIPPED, noSpace.outcome)
        storage.available = INITIAL_SPACE

        storage.valid = false
        val invalid = useCase(TREE, NAME)
        assertEquals(ScheduledFillReason.FILL_STORAGE_UNAVAILABLE, invalid.reason)
        assertEquals(ScheduledFillOutcome.ERROR, invalid.outcome)
        storage.valid = true

        storage.unknownSpace = true
        assertEquals(ScheduledFillReason.FILL_MEASUREMENT_UNAVAILABLE, useCase(TREE, NAME).reason)
        storage.unknownSpace = false

        storage.writeFails = true
        assertEquals(ScheduledFillReason.FILL_WRITE_FAILED, useCase(TREE, NAME).reason)
        assertFalse(journal.began && journal.pending != null)
    }

    @Test
    fun `a live run elsewhere makes the scheduled run a skip`() = runTest {
        val gate = CompletableDeferred<Unit>()
        storage.writeGate = gate
        val interactive = async { engine.run(target, FILLER_RESERVE_BYTES) }
        runCurrent()

        val busy = useCase(TREE, NAME)

        assertEquals(ScheduledFillReason.FILL_BUSY, busy.reason)
        assertEquals(ScheduledFillOutcome.SKIPPED, busy.outcome)
        gate.complete(Unit)
        interactive.await()
    }

    @Test
    fun `a folder off the local volumes is refused before the filler runs`() = runTest {
        resolver.place = null

        val result = useCase(TREE, NAME)

        assertEquals(ScheduledFillReason.FILL_NOT_LOCAL, result.reason)
        assertFalse(journal.began)
    }

    @Test
    fun `an earlier session is cleaned first, and one that stays blocks the run`() = runTest {
        journal.pending = FillerSession("old", target)
        storage.cleanupSucceeds = false

        val blocked = useCase(TREE, NAME)

        assertEquals(ScheduledFillReason.FILL_CLEANUP_PENDING, blocked.reason)
        assertTrue(storage.cleanupAttempts >= 1)
        assertFalse(journal.began)

        storage.cleanupSucceeds = true

        assertEquals(ScheduledFillOutcome.OK, useCase(TREE, NAME).outcome)
    }

    @Test
    fun `only a writable local place is offered for saving`() = runTest {
        storage.valid = false

        assertNull(useCase.usablePlace(TREE))

        storage.valid = true

        assertEquals(place, useCase.usablePlace(TREE))
    }

    @Test
    fun `a reason reads back from its stored name and a retired name reads as none`() {
        ScheduledFillReason.entries.forEach { assertEquals(it, ScheduledFillReason.fromName(it.name)) }
        assertNull(ScheduledFillReason.fromName("RETIRED"))
        assertNull(ScheduledFillReason.fromName(null))
    }

    private class FakeResolver(var place: FillerPlace?) : FillerTargetResolver {
        override suspend fun grant(location: String): Boolean = true
        override suspend fun place(location: String): FillerPlace? = place
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
        var valid = true
        var unknownSpace = false
        var available = INITIAL_SPACE
        var writeFails = false
        var cleanupSucceeds = true
        var cleanupAttempts = 0
        var lowest = INITIAL_SPACE
        var writeGate: CompletableDeferred<Unit>? = null

        override suspend fun validate(target: FillerTarget): Boolean = valid
        override suspend fun availableBytes(target: FillerTarget): Long? = if (unknownSpace) null else available
        override suspend fun create(session: FillerSession, index: Int): FillerFile = FillerFile("created-$index")

        override suspend fun append(file: FillerFile, count: Int) {
            writeGate?.await()
            check(!writeFails)
            available -= count
            lowest = minOf(lowest, available)
        }

        override suspend fun cleanup(session: FillerSession): Boolean {
            cleanupAttempts++
            return cleanupSucceeds
        }

        override suspend fun discardPendingCreate(session: FillerSession): Boolean = true
    }

    private companion object {
        const val TREE = "content://com.android.externalstorage.documents/tree/1234-5678%3ACard"
        const val NAME = "Card"
        const val INITIAL_SPACE = 2 * FILLER_RESERVE_BYTES
    }
}

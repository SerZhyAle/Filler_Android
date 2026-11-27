package com.sza.filler.domain.filler

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.async
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class FillerEngineTest {
    private val target = FillerTarget("local-tree", "primary")
    private val journal = FakeJournal()
    private val storage = FakeStorage(journal)
    private val engine = FillerEngine(storage, journal)

    @Test
    fun `writes only available space beyond reserve and cleans up`() = runTest {
        val result = engine.run(target, RESERVE)

        assertEquals(FillerResult.Finished(INITIAL_SPACE - RESERVE, true), result)
        assertEquals(RESERVE, storage.available)
        assertTrue(storage.cleaned)
        assertTrue(journal.finished)
        assertTrue(journal.preparedBeforeCreate)
    }

    @Test
    fun `unknown free space refuses before creating session`() = runTest {
        storage.unknownSpace = true

        assertEquals(FillerResult.MeasurementUnavailable, engine.run(target, RESERVE))
        assertFalse(journal.began)
    }

    @Test
    fun `invalid target and insufficient space refuse without writing`() = runTest {
        storage.valid = false
        assertEquals(FillerResult.InvalidTarget, engine.run(target, RESERVE))
        storage.valid = true
        storage.available = RESERVE
        assertEquals(FillerResult.InsufficientSpace, engine.run(target, RESERVE))
        assertFalse(journal.began)
    }

    // S0003: the reserve floor (owner order of 2026-11-13). The same case exists in the unshipped FastMediaSorter
    // working tree after release 48; the last assertion is this port's own.
    @Test
    fun `reserve below the floor refuses before a session begins and the floor itself runs`() = runTest {
        assertEquals(FillerResult.InvalidTarget, engine.run(target, FILLER_MIN_RESERVE_BYTES - 1))
        assertFalse(journal.began)
        assertEquals(INITIAL_SPACE, storage.available)

        assertEquals(
            FillerResult.Finished(INITIAL_SPACE - FILLER_MIN_RESERVE_BYTES, true),
            engine.run(target, FILLER_MIN_RESERVE_BYTES),
        )
        assertTrue(journal.began)
        assertEquals(FILLER_MIN_RESERVE_BYTES, storage.available)
    }

    @Test
    fun `write failure retains journal when cleanup fails`() = runTest {
        storage.writeFails = true
        storage.cleanupSucceeds = false

        assertEquals(FillerResult.Failed(false), engine.run(target, RESERVE))
        assertTrue(storage.cleaned)
        assertFalse(journal.finished)
    }

    @Test
    fun `cancellation attempts cleanup and remains cancellation`() = runTest {
        storage.cancelWrite = true
        var cancelled = false
        try {
            engine.run(target, RESERVE)
        } catch (_: CancellationException) {
            cancelled = true
        }

        assertTrue(cancelled)
        assertTrue(storage.cleaned)
        assertTrue(journal.finished)
    }

    @Test
    fun `second operation is refused until the first is finished`() = runTest {
        val gate = CompletableDeferred<Unit>()
        storage.writeGate = gate
        val first = async { engine.run(target, RESERVE) }
        runCurrent()

        assertEquals(FillerResult.Busy, FillerEngine(storage, journal).run(target, RESERVE))
        gate.complete(Unit)
        first.await()
    }

    @Test
    fun `cancelled coroutine attempts cleanup before it finishes`() = runTest {
        storage.writeGate = CompletableDeferred()
        val job = async { engine.run(target, RESERVE) }
        runCurrent()
        job.cancelAndJoin()

        assertTrue(storage.cleaned)
        assertTrue(journal.finished)
    }

    @Test
    fun `restart exposes pending cleanup and only accepts known sessions`() = runTest {
        val pending = FillerSession("pending", target)
        journal.pending = pending
        val restarted = FillerEngine(storage, journal)

        assertEquals(FillerResult.PendingCleanup, restarted.run(target, RESERVE))
        assertFalse(restarted.retryCleanup(FillerSession("unknown", target)))
        assertFalse(storage.cleaned)
        assertTrue(restarted.retryCleanup(pending))
        assertTrue(storage.cleaned)
        assertEquals(null, journal.pending)
    }

    @Test
    fun `ambiguous cleanup preserves the pending session`() = runTest {
        val pending = FillerSession("pending", target)
        journal.pending = pending
        storage.cleanupSucceeds = false

        assertFalse(engine.retryCleanup(pending))
        assertEquals(pending, journal.pending)
    }

    // S0049: the resume of a session a closed app left unfinished (owner decision of 2026-11-16).

    @Test
    fun `resume writes from the recorded files and cleans up the session`() = runTest {
        val pending = FillerSession("pending", target)
        journal.pending = pending
        journal.recordedFiles = 2
        storage.available = INITIAL_SPACE

        val result = engine.resume(pending, RESERVE)

        assertEquals(FillerResult.Finished(INITIAL_SPACE - RESERVE, true), result)
        assertEquals(2, storage.firstCreatedIndex)
        assertTrue(storage.discarded)
        assertTrue(storage.cleaned)
        assertTrue(journal.finished)
        assertEquals(null, journal.pending)
    }

    @Test
    fun `resume of an unknown session refuses without touching the files`() = runTest {
        assertEquals(FillerResult.InvalidTarget, engine.resume(FillerSession("unknown", target), RESERVE))
        assertFalse(storage.discarded)
        assertFalse(storage.cleaned)
    }

    @Test
    fun `resume at the reserve only ends the session`() = runTest {
        val pending = FillerSession("pending", target)
        journal.pending = pending
        storage.available = RESERVE

        assertEquals(FillerResult.Finished(0, true), engine.resume(pending, RESERVE))
        assertEquals(null, storage.firstCreatedIndex)
        assertTrue(storage.cleaned)
        assertTrue(journal.finished)
    }

    @Test
    fun `undiscardable precommitted create keeps the session pending`() = runTest {
        val pending = FillerSession("pending", target)
        journal.pending = pending
        storage.discardFails = true

        assertEquals(FillerResult.Failed(false), engine.resume(pending, RESERVE))
        assertFalse(storage.cleaned)
        assertEquals(pending, journal.pending)
    }

    @Test
    fun `resume without a measurement changes nothing`() = runTest {
        val pending = FillerSession("pending", target)
        journal.pending = pending
        storage.unknownSpace = true

        assertEquals(FillerResult.MeasurementUnavailable, engine.resume(pending, RESERVE))
        assertFalse(storage.discarded)
        assertFalse(storage.cleaned)
        assertEquals(pending, journal.pending)
    }
    private class FakeJournal : FillerJournal {
        var pending: FillerSession? = null
        var recordedFiles = 0
        var began = false
        var prepared = false
        var preparedBeforeCreate = false
        var finished = false

        override suspend fun pendingSessions(): List<FillerSession> = listOfNotNull(pending)

        override suspend fun begin(target: FillerTarget): FillerSession {
            began = true
            val session = FillerSession("session", target)
            pending = session
            return session
        }

        override suspend fun prepareCreate(session: FillerSession, index: Int) {
            prepared = true
        }

        override suspend fun recordCreated(session: FillerSession, index: Int, file: FillerFile) {
            recordedFiles++
        }

        override suspend fun finish(session: FillerSession) {
            finished = true
            pending = null
        }

        /** Files are created in order, so the count recorded is the next index of a resumed run (S0049). */
        override suspend fun resumeIndex(session: FillerSession): Int = recordedFiles
    }

    private class FakeStorage(private val journal: FakeJournal) : FillerStorage {
        var valid = true
        var unknownSpace = false
        var available = INITIAL_SPACE
        var writeFails = false
        var cancelWrite = false
        var cleanupSucceeds = true
        var discardFails = false
        var cleaned = false
        var discarded = false
        var firstCreatedIndex: Int? = null
            private set
        var writeGate: CompletableDeferred<Unit>? = null

        override suspend fun validate(target: FillerTarget): Boolean = valid
        override suspend fun availableBytes(target: FillerTarget): Long? = if (unknownSpace) null else available

        override suspend fun create(session: FillerSession, index: Int): FillerFile {
            journal.preparedBeforeCreate = journal.prepared
            if (firstCreatedIndex == null) firstCreatedIndex = index
            return FillerFile("created-$index")
        }

        override suspend fun append(file: FillerFile, count: Int) {
            writeGate?.await()
            if (cancelWrite) throw CancellationException("test")
            check(!writeFails)
            available -= count
        }

        override suspend fun cleanup(session: FillerSession): Boolean {
            cleaned = true
            return cleanupSucceeds
        }

        override suspend fun discardPendingCreate(session: FillerSession): Boolean {
            discarded = true
            return !discardFails
        }
    }

    private companion object {
        // The source used 1024 bytes; a reserve below the floor is refused now, so the reserve is the floor.
        const val RESERVE = FILLER_MIN_RESERVE_BYTES
        const val INITIAL_SPACE = 2 * RESERVE
    }
}

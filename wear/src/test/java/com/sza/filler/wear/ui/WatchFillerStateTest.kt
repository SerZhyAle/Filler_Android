package com.sza.filler.wear.ui

import com.sza.filler.domain.filler.FILLER_MIN_RESERVE_BYTES
import com.sza.filler.domain.filler.FILLER_RESERVE_BYTES
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

// The watch screen state (S0029). Its phone counterpart is FillerUiState, covered by FillerUiStatePercentTest and the
// start rule of FillerViewModelReserveTest; these cases are this app's own, the source of the port has none.

class WatchFillerStateTest {
    private val enough = FILLER_RESERVE_BYTES + 1

    private fun state(
        accessible: Boolean = true,
        availableBytes: Long? = enough,
        running: Boolean = false,
        pending: Boolean = false,
        reserveBytes: Long = FILLER_RESERVE_BYTES,
    ) = WatchFillerState(
        accessible = accessible,
        availableBytes = availableBytes,
        running = running,
        pending = pending,
        reserveBytes = reserveBytes,
    )

    @Test
    fun `the reserve stops are the seven of the phone, lowest first`() {
        assertEquals(
            listOf(10L, 25L, 50L, 100L, 250L, 500L, 1024L).map { it shl 20 },
            WatchFillerState.RESERVE_CHOICES_BYTES,
        )
    }

    @Test
    fun `the lowest stop is the engine floor and the highest is the default reserve`() {
        assertEquals(FILLER_MIN_RESERVE_BYTES, WatchFillerState.RESERVE_CHOICES_BYTES.first())
        assertEquals(FILLER_RESERVE_BYTES, WatchFillerState.RESERVE_CHOICES_BYTES.last())
        assertEquals(FILLER_RESERVE_BYTES, WatchFillerState().reserveBytes)
    }

    @Test
    fun `a measured space above the reserve starts a run`() {
        assertTrue(state().canStart)
        assertTrue(state(availableBytes = FILLER_MIN_RESERVE_BYTES + 1, reserveBytes = FILLER_MIN_RESERVE_BYTES).canStart)
    }

    @Test
    fun `a space equal to or below the reserve never starts a run`() {
        assertFalse(state(availableBytes = FILLER_RESERVE_BYTES).canStart)
        assertFalse(state(availableBytes = FILLER_RESERVE_BYTES - 1).canStart)
        assertFalse(state(availableBytes = 0).canStart)
    }

    @Test
    fun `an unknown space never starts a run`() {
        assertFalse(state(availableBytes = null).canStart)
        assertFalse(state(availableBytes = null, reserveBytes = FILLER_MIN_RESERVE_BYTES).canStart)
    }

    @Test
    fun `a run, a pending cleanup or an inaccessible place never starts a run`() {
        assertFalse(state(running = true).canStart)
        assertFalse(state(pending = true).canStart)
        assertFalse(state(accessible = false).canStart)
    }

    @Test
    fun `the reserve index is the position of the stop and an unknown value reads as the top stop`() {
        assertEquals(0, state(reserveBytes = FILLER_MIN_RESERVE_BYTES).reserveIndex)
        assertEquals(2, state(reserveBytes = 50L shl 20).reserveIndex)
        assertEquals(6, state().reserveIndex)
        assertEquals(6, state(reserveBytes = 5L shl 20).reserveIndex)
    }

    @Test
    fun `the reserve can move down from the top and up from the floor and never past either end`() {
        val top = state()
        assertTrue(top.canLowerReserve)
        assertFalse(top.canRaiseReserve)

        val floor = state(reserveBytes = FILLER_MIN_RESERVE_BYTES)
        assertFalse(floor.canLowerReserve)
        assertTrue(floor.canRaiseReserve)

        val middle = state(reserveBytes = 100L shl 20)
        assertTrue(middle.canLowerReserve)
        assertTrue(middle.canRaiseReserve)
    }

    @Test
    fun `the reserve cannot move while a run is going`() {
        val running = state(running = true, reserveBytes = 100L shl 20)
        assertFalse(running.canLowerReserve)
        assertFalse(running.canRaiseReserve)
    }

    @Test
    fun `percent is written over planned`() {
        assertEquals(25, WatchFillerState(plannedBytes = 400, writtenBytes = 100).percentDone)
    }

    @Test
    fun `percent is zero while nothing is planned`() {
        assertEquals(0, WatchFillerState(plannedBytes = 0, writtenBytes = 100).percentDone)
        assertEquals(0, WatchFillerState(plannedBytes = -5, writtenBytes = 100).percentDone)
    }

    @Test
    fun `percent never passes a hundred or goes below zero`() {
        assertEquals(100, WatchFillerState(plannedBytes = 1_000, writtenBytes = 1_500).percentDone)
        assertEquals(0, WatchFillerState(plannedBytes = 1_000, writtenBytes = -50).percentDone)
    }

    @Test
    fun `the selection problems are the verdicts about the place as measured`() {
        assertEquals(
            setOf(
                WatchFillerOutcome.NO_PLACE,
                WatchFillerOutcome.NO_ACCESS,
                WatchFillerOutcome.MEASUREMENT_UNAVAILABLE,
                WatchFillerOutcome.INSUFFICIENT_SPACE,
            ),
            WatchFillerState.SELECTION_PROBLEMS,
        )
    }
}

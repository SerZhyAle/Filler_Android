package com.sza.filler.ui.filler

import org.junit.Assert.assertEquals
import org.junit.Test

// New in this app (S0009): the source has no test for the percent, which its state computes the same way.
class FillerUiStatePercentTest {
    @Test
    fun `percent is written over planned`() {
        assertEquals(25, FillerUiState(plannedBytes = 400, writtenBytes = 100).percentDone)
    }

    @Test
    fun `percent is zero while nothing is planned`() {
        assertEquals(0, FillerUiState(plannedBytes = 0, writtenBytes = 100).percentDone)
        assertEquals(0, FillerUiState(plannedBytes = -5, writtenBytes = 100).percentDone)
    }

    @Test
    fun `percent never passes a hundred`() {
        assertEquals(100, FillerUiState(plannedBytes = 1_000, writtenBytes = 1_500).percentDone)
    }

    @Test
    fun `percent never goes below zero`() {
        assertEquals(0, FillerUiState(plannedBytes = 1_000, writtenBytes = -50).percentDone)
    }
}

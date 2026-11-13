package com.sza.filler.buildlogic

import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class VersionStampTest {
    @Test
    fun contractExampleRendersNameAndCode() {
        val stamp = VersionStamp.fromInstant("2609262322")
        assertEquals("2.60.9262.322", stamp.name)
        assertEquals(260926232, stamp.code)
    }

    @Test
    fun clockReadingRendersTheSameInstant() {
        val stamp = VersionStamp.fromClock(LocalDateTime.of(2026, 11, 10, 21, 40, 59))
        assertEquals(VersionStamp.fromInstant("2611102140"), stamp)
        assertEquals("2.61.1102.140", stamp.name)
        assertEquals(261110214, stamp.code)
    }

    @Test
    fun lastDigitOfTheCodeIsTheMinuteBandOfTen() {
        val expectedBand = mapOf("00" to 0, "09" to 0, "10" to 1, "29" to 2, "30" to 3, "49" to 4, "50" to 5, "59" to 5)
        for ((minute, band) in expectedBand) {
            val stamp = VersionStamp.fromInstant("26092623$minute")
            assertEquals("minute $minute", 26092623 * 10 + band, stamp.code)
        }
    }

    @Test
    fun laterSlotsAlwaysOrderAboveEarlierOnes() {
        val ascending = listOf(
            "2609262309", "2609262310", "2609262359", "2609270000",
            "2612312359", "2701010000",
            "2802282359", "2802290000", "2802290010", "2803010000",
            "9912312359",
        )
        val codes = ascending.map { VersionStamp.fromInstant(it).code }
        for (i in 1 until codes.size) {
            assertTrue("${ascending[i]} after ${ascending[i - 1]}", codes[i] > codes[i - 1])
        }
    }

    @Test
    fun anInstantThatIsNotARealDateAndTimeIsRefused() {
        val refused = listOf(
            "", "260926232", "26092623222", "26o9262322",
            "2613010000", "2600010000", "2604310000", "2702290000", "2609262400", "2609262360",
        )
        for (instant in refused) {
            assertThrows("'$instant'", IllegalArgumentException::class.java) { VersionStamp.fromInstant(instant) }
        }
        assertEquals("2.80.2290.000", VersionStamp.fromInstant("2802290000").name)
    }

    @Test
    fun noPinIsNoPair() {
        assertNull(VersionStamp.fromPin(null, null))
    }

    @Test
    fun aPinnedPairOfOneInstantIsAccepted() {
        val stamp = VersionStamp.fromInstant("2611102140")
        assertEquals(stamp, VersionStamp.fromPin(stamp.name, stamp.code.toString()))
    }

    @Test
    fun aOneSidedPinIsRefused() {
        assertThrows(IllegalArgumentException::class.java) { VersionStamp.fromPin("2.60.9262.322", null) }
        assertThrows(IllegalArgumentException::class.java) { VersionStamp.fromPin(null, "260926232") }
    }

    @Test
    fun aPairThatDoesNotDescribeOneInstantIsRefused() {
        // Code of another slot, code in another family's band (the watch band 6..9), a malformed name,
        // a name that decodes to no calendar date, a code with a sign or a space.
        val refused = listOf(
            "2.60.9262.322" to "260926231",
            "2.60.9262.322" to "260926237",
            "2.60.9262.322" to "260926233",
            "2.60.9262" to "260926232",
            "2.61.3202.322" to "261320232",
            "2.60.9262.322" to "+260926232",
            "2.60.9262.322" to " 260926232",
        )
        for ((name, code) in refused) {
            assertThrows("$name / $code", IllegalArgumentException::class.java) { VersionStamp.fromPin(name, code) }
        }
    }
}

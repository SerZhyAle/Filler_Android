package com.sza.filler.buildlogic

import com.sza.filler.buildlogic.VersionStamp.Family.PHONE
import com.sza.filler.buildlogic.VersionStamp.Family.WATCH
import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class VersionStampTest {
    @Test
    fun contractExampleRendersNameAndCode() {
        val stamp = VersionStamp.fromInstant("2609262322", PHONE)
        assertEquals("2.60.9262.322", stamp.name)
        assertEquals(260926232, stamp.code)
    }

    @Test
    fun contractExampleRendersTheWatchCodeInItsOwnBand() {
        val stamp = VersionStamp.fromInstant("2609262322", WATCH)
        assertEquals("2.60.9262.322", stamp.name)
        assertEquals(260926237, stamp.code)
    }

    @Test
    fun clockReadingRendersTheSameInstant() {
        val now = LocalDateTime.of(2026, 11, 10, 21, 40, 59)
        assertEquals("2611102140", VersionStamp.instantOfClock(now))

        val phone = VersionStamp.fromClock(now, PHONE)
        assertEquals(VersionStamp.fromInstant("2611102140", PHONE), phone)
        assertEquals("2.61.1102.140", phone.name)
        assertEquals(261110214, phone.code)

        val watch = VersionStamp.fromClock(now, WATCH)
        assertEquals(VersionStamp.fromInstant("2611102140", WATCH), watch)
        assertEquals("2.61.1102.140", watch.name)
        assertEquals(261110218, watch.code)
    }

    @Test
    fun lastDigitOfThePhoneCodeIsTheMinuteBandOfTen() {
        val expectedBand = mapOf("00" to 0, "09" to 0, "10" to 1, "29" to 2, "30" to 3, "49" to 4, "50" to 5, "59" to 5)
        for ((minute, band) in expectedBand) {
            val stamp = VersionStamp.fromInstant("26092623$minute", PHONE)
            assertEquals("minute $minute", 26092623 * 10 + band, stamp.code)
        }
    }

    @Test
    fun lastDigitOfTheWatchCodeIsTheMinuteBandOfFifteenAboveSix() {
        val expectedBand = mapOf("00" to 6, "14" to 6, "15" to 7, "29" to 7, "30" to 8, "44" to 8, "45" to 9, "59" to 9)
        for ((minute, band) in expectedBand) {
            val stamp = VersionStamp.fromInstant("26092623$minute", WATCH)
            assertEquals("minute $minute", 26092623 * 10 + band, stamp.code)
        }
    }

    @Test
    fun theTwoFamiliesNeverRenderOneCodeAndShareOneName() {
        for (minute in 0..59) {
            val instant = "26092623" + minute.toString().padStart(2, '0')
            val phone = VersionStamp.fromInstant(instant, PHONE)
            val watch = VersionStamp.fromInstant(instant, WATCH)
            assertEquals("minute $minute", phone.name, watch.name)
            assertNotEquals("minute $minute", phone.code, watch.code)
            assertTrue("minute $minute phone band", phone.code % 10 in 0..5)
            assertTrue("minute $minute watch band", watch.code % 10 in 6..9)
        }
    }

    @Test
    fun laterSlotsAlwaysOrderAboveEarlierOnes() {
        // Each list is ascending by the family's own slot (10 minutes for the phone, 15 for the watch):
        // two builds inside one slot are one release (rule 4), so no pair of them is listed.
        val ascending = mapOf(
            PHONE to listOf(
                "2609262309", "2609262310", "2609262359", "2609270000",
                "2612312359", "2701010000",
                "2802282359", "2802290000", "2802290010", "2803010000",
                "9912312359",
            ),
            WATCH to listOf(
                "2609262314", "2609262315", "2609262330", "2609262345", "2609270000",
                "2612312359", "2701010000",
                "2802282359", "2802290000", "2802290015", "2803010000",
                "9912312359",
            ),
        )
        for ((family, instants) in ascending) {
            val codes = instants.map { VersionStamp.fromInstant(it, family).code }
            for (i in 1 until codes.size) {
                assertTrue("$family ${instants[i]} after ${instants[i - 1]}", codes[i] > codes[i - 1])
            }
        }
    }

    @Test
    fun twoBuildsInOneSlotAreOneRelease() {
        assertEquals(
            VersionStamp.fromInstant("2609262310", PHONE).code,
            VersionStamp.fromInstant("2609262319", PHONE).code,
        )
        assertEquals(
            VersionStamp.fromInstant("2609262315", WATCH).code,
            VersionStamp.fromInstant("2609262329", WATCH).code,
        )
    }

    @Test
    fun anInstantThatIsNotARealDateAndTimeIsRefused() {
        val refused = listOf(
            "", "260926232", "26092623222", "26o9262322",
            "2613010000", "2600010000", "2604310000", "2702290000", "2609262400", "2609262360",
        )
        for (family in VersionStamp.Family.entries) {
            for (instant in refused) {
                assertThrows("$family '$instant'", IllegalArgumentException::class.java) {
                    VersionStamp.fromInstant(instant, family)
                }
            }
            assertEquals("2.80.2290.000", VersionStamp.fromInstant("2802290000", family).name)
        }
    }

    @Test
    fun noPinIsNoPair() {
        for (family in VersionStamp.Family.entries) {
            assertNull(VersionStamp.fromPin(null, null, family))
        }
    }

    @Test
    fun aPinnedPairOfOneInstantIsAcceptedByItsOwnFamily() {
        for (family in VersionStamp.Family.entries) {
            val stamp = VersionStamp.fromInstant("2611102140", family)
            assertEquals(stamp, VersionStamp.fromPin(stamp.name, stamp.code.toString(), family))
        }
    }

    @Test
    fun aPinNamesOneInstantAndEachFamilyRendersItInItsOwnBand() {
        // One release pins one name for both apps (rule 1); a module takes the pinned instant whichever
        // registered family's code the orchestrator passed, and carries the code of its own family.
        val phone = VersionStamp.fromInstant("2609262322", PHONE)
        val watch = VersionStamp.fromInstant("2609262322", WATCH)
        for (pinnedCode in listOf(phone.code, watch.code)) {
            assertEquals(phone, VersionStamp.fromPin("2.60.9262.322", pinnedCode.toString(), PHONE))
            assertEquals(watch, VersionStamp.fromPin("2.60.9262.322", pinnedCode.toString(), WATCH))
        }
    }

    @Test
    fun aOneSidedPinIsRefused() {
        for (family in VersionStamp.Family.entries) {
            assertThrows(IllegalArgumentException::class.java) { VersionStamp.fromPin("2.60.9262.322", null, family) }
            assertThrows(IllegalArgumentException::class.java) { VersionStamp.fromPin(null, "260926232", family) }
        }
    }

    @Test
    fun aPairThatDoesNotDescribeOneInstantIsRefused() {
        // Code of another slot, a code in no family's band for the instant (2609262322 is phone 2, watch 7),
        // a malformed name, a name that decodes to no calendar date, a code with a sign or a space.
        val refused = listOf(
            "2.60.9262.322" to "260926231",
            "2.60.9262.322" to "260926233",
            "2.60.9262.322" to "260926236",
            "2.60.9262.322" to "260926238",
            "2.60.9262.322" to "260926239",
            "2.60.9262.322" to "260926227",
            "2.60.9262" to "260926232",
            "2.61.3202.322" to "261320232",
            "2.60.9262.322" to "+260926232",
            "2.60.9262.322" to " 260926232",
            "2.60.9262.322" to "+260926237",
        )
        for (family in VersionStamp.Family.entries) {
            for ((name, code) in refused) {
                assertThrows("$family $name / $code", IllegalArgumentException::class.java) {
                    VersionStamp.fromPin(name, code, family)
                }
            }
        }
    }
}

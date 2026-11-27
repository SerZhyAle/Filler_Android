package com.sza.filler.data.schedule

import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId

// The slot arithmetic of the scheduled fill (S0025): pure java.time, no Android runtime needed.
class FillScheduleSlotsTest {
    private val zone = ZoneId.of("Europe/Kyiv")
    private val day = LocalDate.of(2026, 11, 14).toEpochDay()

    private fun at(date: LocalDate, hour: Int, minute: Int = 0): Long =
        LocalDateTime.of(date, java.time.LocalTime.of(hour, minute)).atZone(zone).toInstant().toEpochMilli()

    private fun schedule(minute: Int, interval: Int, firstDay: Long = day) = FillSchedule(
        id = "s",
        location = "loc",
        folderName = "Card",
        volumeName = "SD card",
        minuteOfDay = minute,
        intervalDays = interval,
        firstDay = firstDay,
        enabled = true,
        revision = 1L,
    )

    @Test
    fun `a time still ahead today starts today, a passed one tomorrow`() {
        val today = LocalDate.ofEpochDay(day)

        assertEquals(day, FillScheduleSlots.firstDay(3 * 60, at(today, 2), zone))
        assertEquals(day + 1, FillScheduleSlots.firstDay(3 * 60, at(today, 3), zone))
        assertEquals(day + 1, FillScheduleSlots.firstDay(3 * 60, at(today, 4), zone))
    }

    @Test
    fun `the next slot is the first one strictly after now`() {
        val today = LocalDate.ofEpochDay(day)
        val daily = schedule(3 * 60, 1)

        assertEquals(at(today, 3), FillScheduleSlots.nextSlot(daily, at(today, 1), zone))
        assertEquals(at(today.plusDays(1), 3), FillScheduleSlots.nextSlot(daily, at(today, 3), zone))
    }

    @Test
    fun `an interval of several days keeps its phase from the first day`() {
        val today = LocalDate.ofEpochDay(day)
        val everyThree = schedule(3 * 60, 3)

        assertEquals(at(today.plusDays(3), 3), FillScheduleSlots.nextSlot(everyThree, at(today, 4), zone))
        assertEquals(at(today.plusDays(6), 3), FillScheduleSlots.nextSlot(everyThree, at(today.plusDays(4), 0), zone))
        assertEquals(at(today.plusDays(30), 3), FillScheduleSlots.nextSlot(everyThree, at(today.plusDays(28), 12), zone))
    }

    @Test
    fun `a first day in the future is the next slot`() {
        val today = LocalDate.ofEpochDay(day)
        val later = schedule(22 * 60 + 30, 7, firstDay = day + 2)

        assertEquals(at(today.plusDays(2), 22, 30), FillScheduleSlots.nextSlot(later, at(today, 23), zone))
    }

    @Test
    fun `a slot in the spring-forward gap moves to the existing hour`() {
        val gapDay = LocalDate.of(2026, 3, 29)
        val night = schedule(3 * 60 + 30, 1, firstDay = gapDay.toEpochDay())

        val slot = FillScheduleSlots.nextSlot(night, at(gapDay, 0), zone)

        assertEquals(gapDay, java.time.Instant.ofEpochMilli(slot).atZone(zone).toLocalDate())
    }

    @Test
    fun `today is the local epoch day`() {
        assertEquals(day, FillScheduleSlots.today(at(LocalDate.ofEpochDay(day), 0, 30), zone))
    }
}

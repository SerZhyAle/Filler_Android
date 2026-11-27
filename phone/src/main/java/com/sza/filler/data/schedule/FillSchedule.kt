package com.sza.filler.data.schedule

import com.sza.filler.domain.filler.ScheduledFillOutcome
import com.sza.filler.domain.filler.ScheduledFillReason
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId

// This product's own (S0025). Deliberate difference from FastMediaSorter's ScheduledOperation (release 48,
// domain/model/ScheduledOperation.kt), which serves every operation type: a Filler schedule needs no target
// resource, file-type mask, time filter, overwrite flag or watch message - only the folder, the time of day and
// how many days lie between two runs. The interval is whole days because the daily cap (S0025 Q2) admits at most
// one unattended fill a day, so a shorter interval could never run more often.

/** A saved scheduled fill. [location] is the folder address the Filler writes to, [folderName] and [volumeName] are
 *  the names the person saw when saving it. Slots fall on [firstDay] + k * [intervalDays] at [minuteOfDay]. */
data class FillSchedule(
    val id: String,
    val location: String,
    val folderName: String,
    val volumeName: String,
    val minuteOfDay: Int,
    val intervalDays: Int,
    val firstDay: Long,
    val enabled: Boolean,
    /** Changes on every edit, so a slot queued for an older version of the schedule is recognised and dropped. */
    val revision: Long,
)

/** One attempt of a schedule, whatever its outcome (S0025 criterion 5). [reason] is null for a success. */
data class FillHistoryEntry(
    val scheduleId: String,
    val folderName: String,
    val volumeName: String,
    val dueAt: Long,
    val startedAt: Long,
    val outcome: ScheduledFillOutcome,
    val reason: ScheduledFillReason?,
    val writtenBytes: Long,
)

/** The slot arithmetic of a schedule, in the device's time zone; daylight-saving gaps move a slot as LocalTime does. */
object FillScheduleSlots {
    /** The choices of the editor, in days. */
    val INTERVAL_CHOICES = listOf(1, 2, 3, 7, 14, 30)

    const val MINUTES_PER_DAY = 24 * 60

    /** A slot later than this after its due time is reported as delayed by the system. */
    const val LATE_AFTER_MILLIS = 15L * 60 * 1000

    /** The first day a new or edited schedule runs: today when its time is still ahead, otherwise tomorrow. */
    fun firstDay(minuteOfDay: Int, now: Long, zone: ZoneId = ZoneId.systemDefault()): Long {
        val today = Instant.ofEpochMilli(now).atZone(zone).toLocalDate()
        return if (slotAt(today.toEpochDay(), minuteOfDay, zone) > now) today.toEpochDay() else today.toEpochDay() + 1
    }

    /** The first slot strictly after [now]. */
    fun nextSlot(schedule: FillSchedule, now: Long, zone: ZoneId = ZoneId.systemDefault()): Long {
        val interval = schedule.intervalDays.coerceAtLeast(1).toLong()
        val today = Instant.ofEpochMilli(now).atZone(zone).toLocalDate().toEpochDay()
        var day = if (today <= schedule.firstDay) {
            schedule.firstDay
        } else {
            schedule.firstDay + Math.floorDiv(today - schedule.firstDay, interval) * interval
        }
        while (slotAt(day, schedule.minuteOfDay, zone) <= now) day += interval
        return slotAt(day, schedule.minuteOfDay, zone)
    }

    fun slotAt(day: Long, minuteOfDay: Int, zone: ZoneId = ZoneId.systemDefault()): Long =
        LocalDate.ofEpochDay(day)
            .atTime(LocalTime.of(minuteOfDay / 60, minuteOfDay % 60))
            .atZone(zone)
            .toInstant()
            .toEpochMilli()

    fun today(now: Long, zone: ZoneId = ZoneId.systemDefault()): Long =
        Instant.ofEpochMilli(now).atZone(zone).toLocalDate().toEpochDay()
}

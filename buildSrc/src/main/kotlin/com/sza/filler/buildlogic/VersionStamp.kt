package com.sza.filler.buildlogic

import java.time.LocalDateTime
import java.time.YearMonth
import java.time.format.DateTimeFormatter

/**
 * PACKAGE-VERSIONING, Android profile (rules 1 to 6), for the phone family.
 *
 * One instant, `yyMMddHHmm` of the build machine's local wall clock, renders both fields:
 * versionName `Y.YM.MDDH.Hmm` is those ten digits with a dot after the first, third and seventh,
 * versionCode is `yyMMddHH * 10 + p`, and `p` is the family's band map of the minute
 * (`floor(minute / 10)`, band 0..5). Nothing here is typed by hand and nothing is parsed out of a
 * version except to check a pinned pair.
 */
object VersionStamp {
    /** The two renderings of one instant. */
    data class Stamp(val name: String, val code: Int)

    private val INSTANT = Regex("""\d{10}""")
    private val NAME = Regex("""\d\.\d{2}\.\d{4}\.\d{3}""")
    private val CLOCK_FORMAT = DateTimeFormatter.ofPattern("yyMMddHHmm")

    fun fromClock(now: LocalDateTime): Stamp = fromInstant(now.format(CLOCK_FORMAT))

    fun fromInstant(instant: String): Stamp {
        require(INSTANT.matches(instant)) { "The instant must be ten digits, yyMMddHHmm; got '$instant'." }
        val year = 2000 + instant.substring(0, 2).toInt()
        val month = instant.substring(2, 4).toInt()
        val day = instant.substring(4, 6).toInt()
        val hour = instant.substring(6, 8).toInt()
        val minute = instant.substring(8, 10).toInt()
        require(month in 1..12) { "The instant '$instant' has no month $month." }
        require(day in 1..YearMonth.of(year, month).lengthOfMonth()) {
            "The instant '$instant' has no day $day in $year-$month."
        }
        require(hour in 0..23) { "The instant '$instant' has no hour $hour." }
        require(minute in 0..59) { "The instant '$instant' has no minute $minute." }

        val name = "${instant[0]}.${instant.substring(1, 3)}.${instant.substring(3, 7)}.${instant.substring(7)}"
        val code = instant.substring(0, 8).toInt() * 10 + minute / 10
        return Stamp(name, code)
    }

    /**
     * Rule 5: a release orchestrator pins versionName and versionCode together or not at all, and the
     * pair always wins over the clock. A pair that does not describe one instant of this family's
     * partition is refused. Returns null when nothing is pinned.
     */
    fun fromPin(name: String?, code: String?): Stamp? {
        if (name == null && code == null) return null
        require(name != null && code != null) {
            "versionName and versionCode are pinned together or not at all."
        }
        require(NAME.matches(name)) { "The pinned versionName must be Y.YM.MDDH.Hmm; got '$name'." }
        val expected = fromInstant(name.replace(".", ""))
        require(code.toIntOrNull() == expected.code && code.all(Char::isDigit)) {
            "The pinned pair does not describe one instant: versionName $name implies versionCode " +
                "${expected.code}, got '$code'."
        }
        return expected
    }
}

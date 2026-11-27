package com.sza.filler.buildlogic

import java.time.LocalDateTime
import java.time.YearMonth
import java.time.format.DateTimeFormatter

/**
 * PACKAGE-VERSIONING, Android profile (rules 1 to 6), for the two families of the one application id
 * `com.sza.filler` (registered in the rule 3 band table since 0.8).
 *
 * One instant, `yyMMddHHmm` of the build machine's local wall clock, renders both fields:
 * versionName `Y.YM.MDDH.Hmm` is those ten digits with a dot after the first, third and seventh,
 * versionCode is `yyMMddHH * 10 + p`, and `p` is the family's band map of the minute. Nothing here is
 * typed by hand and nothing is parsed out of a version except to check a pinned pair.
 */
object VersionStamp {
    /**
     * The registered package families. They share one application id, so their bands of the last code
     * digit are disjoint, and each family derives its code from the instant alone: no family ever needs
     * another family's code to stay clear of it.
     */
    enum class Family {
        /** `com.sza.filler`, band 0..5, a 10 minute slot: `floor(minute / 10)`. */
        PHONE,

        /** `com.sza.filler` (shared id), band 6..9, a 15 minute slot: `6 + floor(minute / 15)`. */
        WATCH;

        fun band(minute: Int): Int = when (this) {
            PHONE -> minute / 10
            WATCH -> 6 + minute / 15
        }
    }

    /** The two renderings of one instant. */
    data class Stamp(val name: String, val code: Int)

    private val INSTANT = Regex("""\d{10}""")
    private val NAME = Regex("""\d\.\d{2}\.\d{4}\.\d{3}""")
    private val CLOCK_FORMAT = DateTimeFormatter.ofPattern("yyMMddHHmm")

    /** The instant of a clock reading, `yyMMddHHmm`. The build reads the clock once per invocation (rule 6). */
    fun instantOfClock(now: LocalDateTime): String = now.format(CLOCK_FORMAT)

    fun fromClock(now: LocalDateTime, family: Family): Stamp = fromInstant(instantOfClock(now), family)

    fun fromInstant(instant: String, family: Family): Stamp {
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
        val code = instant.substring(0, 8).toInt() * 10 + family.band(minute)
        return Stamp(name, code)
    }

    /**
     * Rule 5: a release orchestrator pins versionName and versionCode together or not at all, and the
     * pinned instant always wins over the clock. Returns null when nothing is pinned.
     *
     * The pair must describe one instant: the name encodes it, and the code must be the rendering of that
     * instant by one of the registered families. Gradle configures every module of a build, built or not,
     * and a release that ships both apps pins one name for both (rule 1: a byte-identical versionName), so
     * each module takes the pinned instant and renders it in its own family's band. A pinned code in no
     * family's band for that instant is refused.
     */
    fun fromPin(name: String?, code: String?, family: Family): Stamp? {
        if (name == null && code == null) return null
        require(name != null && code != null) {
            "versionName and versionCode are pinned together or not at all."
        }
        require(NAME.matches(name)) { "The pinned versionName must be Y.YM.MDDH.Hmm; got '$name'." }
        val instant = name.replace(".", "")
        val expected = fromInstant(instant, family)
        val registered = Family.entries.map { fromInstant(instant, it).code }
        require(code.all(Char::isDigit) && code.toIntOrNull() in registered) {
            "The pinned pair does not describe one instant: versionName $name implies versionCode " +
                "${registered.joinToString(" or ")}, got '$code'."
        }
        return expected
    }
}

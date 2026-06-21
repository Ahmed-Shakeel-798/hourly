package com.ahmedshakeel.hourly

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Mirrors the Dart tests in `test/usage_service_test.dart` for the native
 * screen-time calc, plus the widget's mood-tier boundaries.
 */
class ScreenTimeTest {

    private val h = 3_600_000L
    private val min = 60_000L
    private val start = 0L
    private val end = 24 * h

    private fun resume(ms: Long, pkg: String) = UsageEvent(1, ms, pkg)
    private fun pause(ms: Long, pkg: String) = UsageEvent(2, ms, pkg)

    @Test
    fun countsSimpleInDaySession() {
        val total = dailyForegroundMillis(
            listOf(resume(10 * h, "a"), pause(10 * h + 30 * min, "a")),
            start, end,
        )
        assertEquals(30 * min, total)
    }

    @Test
    fun sessionCrossingMidnightIsClipped() {
        // Resumed 30 min before the day, paused 10 min into it.
        val total = dailyForegroundMillis(
            listOf(resume(-30 * min, "a"), pause(10 * min, "a")),
            start, end,
        )
        assertEquals(10 * min, total) // not the full 40 min
    }

    @Test
    fun previousDaySessionContributesNothing() {
        val total = dailyForegroundMillis(
            listOf(resume(-2 * h, "a"), pause(-1 * h, "a")),
            start, end,
        )
        assertEquals(0L, total)
    }

    @Test
    fun stillForegroundCountsToWindowEnd() {
        val total = dailyForegroundMillis(
            listOf(resume(end - 30 * min, "a")),
            start, end,
        )
        assertEquals(30 * min, total)
    }

    @Test
    fun appSwitchClosesPrevious() {
        val total = dailyForegroundMillis(
            listOf(
                resume(9 * h, "a"),
                resume(9 * h + 15 * min, "b"), // switch without explicit pause
                pause(9 * h + 45 * min, "b"),
            ),
            start, end,
        )
        assertEquals(45 * min, total) // 15 min of a + 30 min of b
    }

    @Test
    fun screenOffEndsSession() {
        val total = dailyForegroundMillis(
            listOf(
                resume(8 * h, "a"),
                UsageEvent(16, 8 * h + 20 * min, "android"), // SCREEN_NON_INTERACTIVE
                resume(12 * h, "a"),
                pause(12 * h + 5 * min, "a"),
            ),
            start, end,
        )
        assertEquals(25 * min, total)
    }

    @Test
    fun moodBoundaries() {
        assertEquals(Mood.GREAT, moodFor(59 * min))
        assertEquals(Mood.GOOD, moodFor(1 * h))
        assertEquals(Mood.GOOD, moodFor(2 * h - 1))
        assertEquals(Mood.MEH, moodFor(2 * h))
        assertEquals(Mood.ANNOYED, moodFor(4 * h))
        assertEquals(Mood.FED_UP, moodFor(6 * h))
        assertEquals(Mood.FED_UP, moodFor(10 * h))
    }

    @Test
    fun everyFaceIsFiveLines() {
        for (mood in Mood.values()) {
            assertEquals(5, mood.face.split("\n").size)
        }
    }
}

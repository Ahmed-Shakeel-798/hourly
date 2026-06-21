package com.ahmedshakeel.hourly

/// Pure screen-time + mood logic for the home-screen widget.
///
/// [dailyForegroundMillis] mirrors `UsageService.foregroundTotals` in
/// `lib/services/usage_service.dart`: it reconstructs foreground intervals from
/// raw usage events and clips them to the day, so a session straddling midnight
/// is split correctly instead of double-counted. Kept free of Android APIs so it
/// can be unit-tested on the JVM.

// Android `UsageEvents.Event` type codes we react to.
private const val EVENT_RESUMED = 1 // ACTIVITY_RESUMED  -> entered foreground
private const val EVENT_PAUSED = 2 // ACTIVITY_PAUSED   -> left foreground
private const val EVENT_STOPPED = 23 // ACTIVITY_STOPPED
private const val EVENT_SCREEN_OFF = 16 // SCREEN_NON_INTERACTIVE
private const val EVENT_SHUTDOWN = 26 // DEVICE_SHUTDOWN

private const val HOUR_MS = 3_600_000L

/** A single foreground/background usage event (minimal, testable shape). */
data class UsageEvent(val type: Int, val timeStampMs: Long, val packageName: String?)

/** A mood tier shown by the widget, with its ASCII "little screen" face. */
enum class Mood(val label: String, val face: String) {
    GREAT("Great", faceOf("|^    ^|", "| \\__/ |")),
    GOOD("Good", faceOf("|o    o|", "| \\_/  |")),
    MEH("Meh", faceOf("|o    o|", "|  --  |")),
    ANNOYED("Annoyed", faceOf("|>    <|", "|  /\\  |")),
    FED_UP("Fed up", faceOf("|>    <|", "| /\\/\\ |")),
    SETUP("Tap to set up", faceOf("|?    ?|", "|  ..  |"));
}

/** Wraps [eyes] and [mouth] (each 8 chars wide) in the little-screen frame. */
private fun faceOf(eyes: String, mouth: String): String = listOf(
    ".------.",
    eyes,
    mouth,
    "'------'",
    "  |__|",
).joinToString("\n")

/** Maps cumulative daily screen time (ms) to a [Mood] tier. */
fun moodFor(millis: Long): Mood = when {
    millis < 1 * HOUR_MS -> Mood.GREAT
    millis < 2 * HOUR_MS -> Mood.GOOD
    millis < 4 * HOUR_MS -> Mood.MEH
    millis < 6 * HOUR_MS -> Mood.ANNOYED
    else -> Mood.FED_UP
}

/**
 * Total foreground (screen-on) time within `[startMs, endMs]`, reconstructed
 * from raw usage [events]. Each foreground interval (ACTIVITY_RESUMED → next
 * pause/stop, screen-off, shutdown, app switch, or the window end) is clipped to
 * the window before being added.
 */
fun dailyForegroundMillis(events: List<UsageEvent>, startMs: Long, endMs: Long): Long {
    val sorted = events.sortedBy { it.timeStampMs }

    var total = 0L
    var fgPkg: String? = null
    var fgStart = 0L
    var open = false

    fun close(stopMs: Long) {
        if (open) {
            val s = fgStart.coerceIn(startMs, endMs)
            val e = stopMs.coerceIn(startMs, endMs)
            if (e > s) total += e - s
        }
        open = false
        fgPkg = null
    }

    for (ev in sorted) {
        when (ev.type) {
            EVENT_RESUMED -> {
                val pkg = ev.packageName
                if (pkg != null) {
                    close(ev.timeStampMs) // close any prior foreground
                    fgPkg = pkg
                    fgStart = ev.timeStampMs
                    open = true
                }
            }
            EVENT_PAUSED, EVENT_STOPPED ->
                if (ev.packageName == fgPkg) close(ev.timeStampMs)
            EVENT_SCREEN_OFF, EVENT_SHUTDOWN -> close(ev.timeStampMs)
        }
    }
    close(endMs)
    return total
}

/** Compact duration string, e.g. `2h 5m`, `45m`, `0m`. Mirrors `formatDuration`. */
fun formatDurationMs(millis: Long): String {
    val totalMin = millis / 60_000
    val h = totalMin / 60
    val m = totalMin % 60
    return when {
        h > 0 && m > 0 -> "${h}h ${m}m"
        h > 0 -> "${h}h"
        totalMin > 0 -> "${m}m"
        else -> "0m"
    }
}

import 'package:usage_stats/usage_stats.dart';

import '../models/app_usage.dart';

/// Wraps the Android UsageStatsManager (via the `usage_stats` plugin).
///
/// Per-day usage is reconstructed from raw foreground/background **events**
/// rather than the pre-aggregated daily buckets returned by `queryUsageStats`.
/// Those buckets report a whole bucket's total even when it only partially
/// overlaps the query window and their boundaries don't line up with local
/// midnight, so a single evening session would be counted in full on *both*
/// yesterday and today. Reconstructing from events lets us clip each foreground
/// interval to the exact day, so a session that straddles midnight is split
/// correctly between the two days.
class UsageService {
  // Android `UsageEvents.Event` type codes we react to.
  static const _resumed = 1; // ACTIVITY_RESUMED  -> entered foreground
  static const _paused = 2; // ACTIVITY_PAUSED   -> left foreground
  static const _stopped = 23; // ACTIVITY_STOPPED
  static const _screenOff = 16; // SCREEN_NON_INTERACTIVE
  static const _shutdown = 26; // DEVICE_SHUTDOWN

  /// Whether the user has granted the special "Usage access" permission.
  Future<bool> hasPermission() async {
    final granted = await UsageStats.checkUsagePermission();
    return granted ?? false;
  }

  /// Opens the system "Usage access" settings page so the user can grant it.
  Future<void> requestPermission() async {
    await UsageStats.grantUsagePermission();
  }

  /// Per-app foreground usage for [day], sorted longest-first.
  Future<List<AppUsage>> usageForDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final isToday = _isSameDay(day, DateTime.now());
    final end = isToday ? DateTime.now() : start.add(const Duration(days: 1));

    // Look back before `start` so a session already in progress at midnight is
    // captured (its ACTIVITY_RESUMED fired the evening before). Intervals are
    // clipped to [start, end] below, so the pre-midnight portion isn't counted.
    final queryStart = start.subtract(const Duration(hours: 12));

    final events = await UsageStats.queryEvents(queryStart, end);
    final totals = foregroundTotals(
      events,
      start.millisecondsSinceEpoch,
      end.millisecondsSinceEpoch,
    );

    final usage = totals.entries
        .map((e) => AppUsage(
              packageName: e.key,
              time: Duration(milliseconds: e.value),
            ))
        .where((u) => u.time.inSeconds > 0)
        .toList()
      ..sort((a, b) => b.time.compareTo(a.time));

    return usage;
  }

  /// Total foreground screen time for [day].
  Future<Duration> totalForDay(DateTime day) async {
    final usage = await usageForDay(day);
    return usage.fold<Duration>(Duration.zero, (sum, u) => sum + u.time);
  }

  /// Sums per-package foreground time (in ms) that falls within
  /// `[startMs, endMs]`, reconstructed from raw usage [events].
  ///
  /// Pure and free of platform calls so it can be unit-tested. Each
  /// foreground interval (ACTIVITY_RESUMED → next ACTIVITY_PAUSED/STOPPED,
  /// screen-off, shutdown, app switch, or the window end) is clipped to the
  /// window before being added.
  static Map<String, int> foregroundTotals(
    List<EventUsageInfo> events,
    int startMs,
    int endMs,
  ) {
    final sorted = [...events]
      ..sort((a, b) => (int.tryParse(a.timeStamp ?? '') ?? 0)
          .compareTo(int.tryParse(b.timeStamp ?? '') ?? 0));

    final totals = <String, int>{};
    String? fgPkg;
    int? fgStart;

    void close(int stopMs) {
      final pkg = fgPkg;
      final startedAt = fgStart;
      if (pkg != null && startedAt != null) {
        final s = _clamp(startedAt, startMs, endMs);
        final e = _clamp(stopMs, startMs, endMs);
        if (e > s) totals[pkg] = (totals[pkg] ?? 0) + (e - s);
      }
      fgPkg = null;
      fgStart = null;
    }

    for (final ev in sorted) {
      final type = int.tryParse(ev.eventType ?? '');
      final ts = int.tryParse(ev.timeStamp ?? '');
      if (type == null || ts == null) continue;
      final pkg = ev.packageName;

      switch (type) {
        case _resumed:
          if (pkg == null) break;
          close(ts); // close any prior foreground (covers a missing pause)
          fgPkg = pkg;
          fgStart = ts;
          break;
        case _paused:
        case _stopped:
          if (pkg == fgPkg) close(ts);
          break;
        case _screenOff:
        case _shutdown:
          close(ts); // user stopped looking at the screen
          break;
      }
    }
    // Whatever was still foreground at the window end (e.g. the app open right
    // now when viewing "today").
    close(endMs);

    return totals;
  }

  static int _clamp(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

import 'package:usage_stats/usage_stats.dart';

import '../models/app_usage.dart';

/// Wraps the Android UsageStatsManager (via the `usage_stats` plugin).
class UsageService {
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

    final List<UsageInfo> infos =
        await UsageStats.queryUsageStats(start, end);

    // The same package can appear in multiple buckets; sum them.
    final totals = <String, int>{};
    for (final info in infos) {
      final pkg = info.packageName;
      final ms = int.tryParse(info.totalTimeInForeground ?? '0') ?? 0;
      if (pkg == null || ms <= 0) continue;
      totals[pkg] = (totals[pkg] ?? 0) + ms;
    }

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

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

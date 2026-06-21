import 'package:flutter_test/flutter_test.dart';
import 'package:hourly/services/usage_service.dart';
import 'package:usage_stats/usage_stats.dart';

EventUsageInfo _ev(int type, int ms, String pkg) =>
    EventUsageInfo(eventType: '$type', timeStamp: '$ms', packageName: pkg);

void main() {
  // The day we compute usage for: [day, day+1).
  final day = DateTime(2026, 6, 20);
  final startMs = day.millisecondsSinceEpoch;
  final endMs = day.add(const Duration(days: 1)).millisecondsSinceEpoch;

  int at(Duration into) => day.add(into).millisecondsSinceEpoch;
  int before(Duration b) => day.subtract(b).millisecondsSinceEpoch;
  int mins(int m) => Duration(minutes: m).inMilliseconds;

  test('counts a simple in-day session', () {
    final totals = UsageService.foregroundTotals([
      _ev(1, at(const Duration(hours: 10)), 'com.webtoon'),
      _ev(2, at(const Duration(hours: 10, minutes: 30)), 'com.webtoon'),
    ], startMs, endMs);
    expect(totals['com.webtoon'], mins(30));
  });

  test('a session crossing midnight only counts the part inside the day', () {
    // Resumed 30 min before midnight, paused 10 min after.
    final totals = UsageService.foregroundTotals([
      _ev(1, before(const Duration(minutes: 30)), 'com.webtoon'),
      _ev(2, at(const Duration(minutes: 10)), 'com.webtoon'),
    ], startMs, endMs);
    expect(totals['com.webtoon'], mins(10)); // not the full 40 min
  });

  test('a session entirely on the previous day contributes nothing', () {
    final totals = UsageService.foregroundTotals([
      _ev(1, before(const Duration(hours: 2)), 'com.webtoon'),
      _ev(2, before(const Duration(hours: 1)), 'com.webtoon'),
    ], startMs, endMs);
    expect(totals.containsKey('com.webtoon'), isFalse);
  });

  test('an app still in the foreground is counted up to the window end', () {
    final totals = UsageService.foregroundTotals([
      _ev(1, at(const Duration(hours: 23, minutes: 30)), 'com.webtoon'),
      // no pause event -> counts the remaining 30 min of the day
    ], startMs, endMs);
    expect(totals['com.webtoon'], mins(30));
  });

  test('switching apps closes the previous one (missing pause is tolerated)',
      () {
    final totals = UsageService.foregroundTotals([
      _ev(1, at(const Duration(hours: 9)), 'a'),
      _ev(1, at(const Duration(hours: 9, minutes: 15)), 'b'),
      _ev(2, at(const Duration(hours: 9, minutes: 45)), 'b'),
    ], startMs, endMs);
    expect(totals['a'], mins(15));
    expect(totals['b'], mins(30));
  });

  test('screen-off ends the current session', () {
    final totals = UsageService.foregroundTotals([
      _ev(1, at(const Duration(hours: 8)), 'com.webtoon'),
      _ev(16, at(const Duration(hours: 8, minutes: 20)), 'android'),
      // resumes again later, separately
      _ev(1, at(const Duration(hours: 12)), 'com.webtoon'),
      _ev(2, at(const Duration(hours: 12, minutes: 5)), 'com.webtoon'),
    ], startMs, endMs);
    expect(totals['com.webtoon'], mins(25));
  });
}

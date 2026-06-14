import 'package:flutter_test/flutter_test.dart';
import 'package:hourly/utils/formatting.dart';

void main() {
  test('formatDuration is compact and human-readable', () {
    expect(formatDuration(const Duration(seconds: 30)), '30s');
    expect(formatDuration(const Duration(minutes: 45)), '45m');
    expect(formatDuration(const Duration(hours: 2, minutes: 5)), '2h 5m');
    expect(formatDuration(const Duration(hours: 3)), '3h');
  });
}

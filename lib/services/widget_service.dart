import 'package:flutter/services.dart';

/// Asks the native side to refresh the home-screen mood widget (see
/// MoodWidgetProvider.kt) so it reflects the latest screen time promptly,
/// rather than waiting for its periodic update.
class WidgetService {
  static const _channel = MethodChannel('com.ahmedshakeel.hourly/apps');

  static Future<void> refresh() async {
    try {
      await _channel.invokeMethod('refreshWidget');
    } catch (_) {
      // No widget placed, or native call unavailable — nothing to do.
    }
  }
}

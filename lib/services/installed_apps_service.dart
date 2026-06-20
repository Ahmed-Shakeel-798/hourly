import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/installed_app.dart';

/// Lists installed apps and deep-links into their notification settings,
/// via a small native MethodChannel (see MainActivity.kt).
class InstalledAppsService {
  static const _channel = MethodChannel('com.ahmedshakeel.hourly/apps');

  /// Launchable apps on the device, sorted by name. Hourly itself is excluded.
  Future<List<InstalledApp>> getInstalledApps({bool icons = true}) async {
    final raw = await _channel
        .invokeMethod<List<dynamic>>('getInstalledApps', {'icons': icons});
    if (raw == null) return const [];
    return raw.map((e) {
      final m = (e as Map).cast<String, dynamic>();
      final iconB64 = m['icon'] as String?;
      return InstalledApp(
        package: m['package'] as String,
        name: m['name'] as String,
        system: m['system'] as bool? ?? false,
        icon: iconB64 != null ? base64Decode(iconB64) : null,
      );
    }).toList();
  }

  /// Opens the system notification settings page for [package].
  /// Returns false if no settings activity could be launched.
  Future<bool> openNotificationSettings(String package) async {
    final ok = await _channel.invokeMethod<bool>(
      'openNotificationSettings',
      {'package': package},
    );
    return ok ?? false;
  }
}

import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/activity_log.dart';
import 'database_service.dart';

const String kCheckinChannelId = 'checkin_channel';
const String kReportChannelId = 'report_channel';
const String kReplyActionId = 'reply_action';
const String kCheckinEnabledKey = 'checkins_enabled';

const int kHourlyCheckinId = 1001; // legacy single repeat id + immediate test
const int kDailyReportId = 2001;

/// Each waking-hour check-in is scheduled at HH:00 with id = base + hour.
const int kHourlyCheckinBaseId = 1100;
const int kCheckinStartHour = 8; // first check-in at 08:00
const int kCheckinEndHour = 22; // last check-in at 22:00 (inclusive)

/// Bumped whenever a check-in is saved, so the UI can refresh itself.
final ValueNotifier<int> logsRevision = ValueNotifier<int>(0);

/// Handles an inline reply that arrives while the app is backgrounded/killed.
/// Must be a top-level function annotated for AOT.
@pragma('vm:entry-point')
void notificationBackgroundHandler(NotificationResponse response) async {
  if (response.actionId != kReplyActionId) return;
  final text = response.input?.trim();
  if (text == null || text.isEmpty) return;

  // We're in a fresh isolate: make sure plugins are registered before DB use.
  DartPluginRegistrant.ensureInitialized();
  await DatabaseService.instance.insertLog(
    ActivityLog(time: DateTime.now(), text: text, source: 'checkin'),
  );
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onForegroundResponse,
      onDidReceiveBackgroundNotificationResponse: notificationBackgroundHandler,
    );

    await _requestAndroidPermissions();
  }

  Future<void> _requestAndroidPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
  }

  /// Foreground inline reply -> persist + refresh UI.
  Future<void> _onForegroundResponse(NotificationResponse response) async {
    if (response.actionId != kReplyActionId) return;
    final text = response.input?.trim();
    if (text == null || text.isEmpty) return;
    await DatabaseService.instance.insertLog(
      ActivityLog(time: DateTime.now(), text: text, source: 'checkin'),
    );
    logsRevision.value++;
  }

  NotificationDetails get _checkinDetails {
    const android = AndroidNotificationDetails(
      kCheckinChannelId,
      'Hourly check-ins',
      channelDescription: 'Asks what you are doing once an hour.',
      importance: Importance.high,
      priority: Priority.high,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          kReplyActionId,
          'Reply',
          allowGeneratedReplies: true,
          inputs: <AndroidNotificationActionInput>[
            AndroidNotificationActionInput(label: 'What are you doing?'),
          ],
          cancelNotification: true,
        ),
      ],
    );
    return const NotificationDetails(android: android);
  }

  /// Schedules a check-in at the top of every waking hour (08:00–22:00),
  /// each repeating daily, with an inline reply field.
  Future<void> scheduleHourlyCheckin() async {
    for (int hour = kCheckinStartHour; hour <= kCheckinEndHour; hour++) {
      await _plugin.zonedSchedule(
        kHourlyCheckinBaseId + hour,
        'Check-in',
        'What are you doing right now?',
        _nextInstanceOf(hour, 0),
        _checkinDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time, // repeat daily at HH:00
      );
    }
  }

  /// Daily reminder at 21:00 that the report is ready.
  Future<void> scheduleDailyReport({int hour = 21, int minute = 0}) async {
    const android = AndroidNotificationDetails(
      kReportChannelId,
      'Daily report',
      channelDescription: 'End-of-day summary reminder.',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    await _plugin.zonedSchedule(
      kDailyReportId,
      'Your daily report is ready',
      'Tap to see today\'s screen time and check-ins.',
      _nextInstanceOf(hour, minute),
      const NotificationDetails(android: android),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Turn the hourly check-in + daily report on, and remember it.
  Future<void> enableCheckins() async {
    await _cancelAllCheckins(); // clear any prior schedule (incl. legacy id)
    await scheduleHourlyCheckin();
    await scheduleDailyReport();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kCheckinEnabledKey, true);
  }

  /// Turn them off and remember it.
  Future<void> disableCheckins() async {
    await _cancelAllCheckins();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kCheckinEnabledKey, false);
  }

  Future<void> _cancelAllCheckins() async {
    await _plugin.cancel(kHourlyCheckinId); // legacy single repeat
    for (int hour = 0; hour < 24; hour++) {
      await _plugin.cancel(kHourlyCheckinBaseId + hour);
    }
    await _plugin.cancel(kDailyReportId);
  }

  /// Whether the user has enabled hourly check-ins.
  Future<bool> isCheckinEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kCheckinEnabledKey) ?? false;
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  /// Fires an immediate check-in — handy for testing the reply flow.
  Future<void> sendTestCheckin() => _plugin.show(
        kHourlyCheckinId,
        'Check-in',
        'What are you doing right now?',
        _checkinDetails,
      );

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}

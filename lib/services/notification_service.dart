import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../models/study_plan.dart';
import 'alarm_service.dart';
import 'storage_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static bool _hasExactAlarmPermission = false;
  static bool _hasNotificationPermission = false;

  static const String _channelId = 'study_alarm_channel_v2';
  static const String _channelName = 'Study Alerts & Reminders';
  static const String _channelDesc =
      'High-priority study alarms with sound and vibration';

  static bool get hasExactAlarmPermission => _hasExactAlarmPermission;
  static bool get hasNotificationPermission => _hasNotificationPermission;

  static Future<void> initialize() async {
    if (_initialized) return;
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    try {
      tzdata.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      } catch (_) {
        tz.setLocalLocation(tz.local);
      }

      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _handleNotificationResponse,
      );

      final androidPlugin =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        // Create high-importance alarm notification channel
        final channel = AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.max,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('study_alarm'),
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 500, 250, 500, 250, 500]),
          audioAttributesUsage: AudioAttributesUsage.alarm,
        );

        await androidPlugin.createNotificationChannel(channel);

        // Request POST_NOTIFICATIONS (Android 13+)
        final notifGranted =
            await androidPlugin.requestNotificationsPermission();
        _hasNotificationPermission = notifGranted ?? false;

        // Check/request exact alarm permission (Android 12+)
        final exactGranted = await androidPlugin.requestExactAlarmsPermission();
        _hasExactAlarmPermission = exactGranted ?? false;
      }

      _initialized = true;
    } catch (e) {
      debugPrint('Notification init notice: $e');
    }
  }

  static void _handleNotificationResponse(NotificationResponse details) {
    if (details.actionId == 'stop') {
      AlarmService.stopAlarm();
      return;
    }
    if (details.actionId == 'snooze') {
      AlarmService.snoozeAlarm();
      return;
    }

    // Tapped body: open active alarm or trigger alert
    final payload = details.payload;
    if (payload != null && payload.isNotEmpty) {
      final reminder = StudyReminder(
        id: details.id ??
            DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
        title: payload,
        hour: DateTime.now().hour,
        minute: DateTime.now().minute,
        enabled: true,
      );
      AlarmService.triggerAlarm(reminder);
    }
  }

  /// Schedule a local reminder with custom sound, vibration, and recurrence
  static Future<void> scheduleReminder(StudyReminder reminder) async {
    if (kIsWeb) return;
    await initialize();

    try {
      final settings = await StorageService.loadReminderSettings();
      final now = tz.TZDateTime.now(tz.local);

      // Determine initial scheduled time
      tz.TZDateTime scheduledDate;
      if (reminder.recurrence == ReminderRecurrence.none &&
          reminder.date != null) {
        scheduledDate = tz.TZDateTime(
          tz.local,
          reminder.date!.year,
          reminder.date!.month,
          reminder.date!.day,
          reminder.hour,
          reminder.minute,
        );
        if (scheduledDate.isBefore(now)) return; // don't schedule past one-offs
      } else {
        scheduledDate = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day,
          reminder.hour,
          reminder.minute,
        );
        if (!scheduledDate.isAfter(now)) {
          scheduledDate = scheduledDate.add(const Duration(days: 1));
        }
      }

      // Vibration pattern
      final vibPatternList = AlarmService.getPatternIntervals(
        reminder.vibrationPattern,
      );
      final int64Vib = Int64List.fromList(vibPatternList);

      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        playSound: settings.soundEnabled && reminder.soundEnabled,
        sound: const RawResourceAndroidNotificationSound('study_alarm'),
        enableVibration: settings.vibrationEnabled && reminder.vibrationEnabled,
        vibrationPattern: int64Vib,
        actions: const [
          AndroidNotificationAction(
            'stop',
            'Stop Alarm',
            cancelNotification: true,
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            'snooze',
            'Snooze (5m)',
            cancelNotification: true,
            showsUserInterface: false,
          ),
        ],
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'study_alarm.wav',
        categoryIdentifier: 'study_alarm',
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      DateTimeComponents? matchComponents;
      switch (reminder.recurrence) {
        case ReminderRecurrence.daily:
          matchComponents = DateTimeComponents.time;
          break;
        case ReminderRecurrence.weekly:
          matchComponents = DateTimeComponents.dayOfWeekAndTime;
          break;
        case ReminderRecurrence.weekdays:
          matchComponents = DateTimeComponents.dayOfWeekAndTime;
          break;
        case ReminderRecurrence.none:
          matchComponents = null;
          break;
      }

      // Attempt exact alarm first, fallback to inexact if restricted
      try {
        await _notifications.zonedSchedule(
          reminder.id,
          '⏰ ${reminder.title}',
          reminder.subjectName != null && reminder.subjectName!.isNotEmpty
              ? 'Study Time: ${reminder.subjectName} — Stay on track!'
              : 'Time for your scheduled study session! Stay consistent.',
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: matchComponents,
          payload: reminder.title,
        );
      } catch (_) {
        // Fallback for devices restricting exact alarms
        await _notifications.zonedSchedule(
          reminder.id,
          '⏰ ${reminder.title}',
          reminder.subjectName != null && reminder.subjectName!.isNotEmpty
              ? 'Study Time: ${reminder.subjectName} — Stay on track!'
              : 'Time for your scheduled study session! Stay consistent.',
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: matchComponents,
          payload: reminder.title,
        );
      }
    } catch (e) {
      debugPrint('Schedule reminder notice: $e');
    }
  }

  /// Cancel a scheduled reminder
  static Future<void> cancelReminder(int id) async {
    if (kIsWeb) return;
    try {
      await _notifications.cancel(id);
    } catch (_) {}
  }

  /// Cancel all scheduled reminders
  static Future<void> cancelAll() async {
    if (kIsWeb) return;
    try {
      await _notifications.cancelAll();
    } catch (_) {}
  }

  /// Test dispatching an immediate alarm notification
  static Future<void> triggerTestNotification() async {
    if (kIsWeb) return;
    await initialize();

    try {
      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('study_alarm'),
        enableVibration: true,
        actions: [
          AndroidNotificationAction('stop', 'Stop Alarm',
              cancelNotification: true),
          AndroidNotificationAction('snooze', 'Snooze (5m)',
              cancelNotification: true),
        ],
      );

      await _notifications.show(
        99999,
        '⏰ Test Study Reminder',
        'Your alarm ringtone & vibration are working properly!',
        const NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      debugPrint('Test notification notice: $e');
    }
  }
}

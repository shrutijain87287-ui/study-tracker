import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ca_inter_tracker/models/study_plan.dart';
import 'package:ca_inter_tracker/services/alarm_service.dart';
import 'package:ca_inter_tracker/services/storage_service.dart';
import 'package:ca_inter_tracker/widgets/active_alarm_dialog.dart';
import 'package:ca_inter_tracker/screens/reminders_screen.dart';
import 'package:ca_inter_tracker/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (MethodCall methodCall) async => 1,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (MethodCall methodCall) async => 1,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('vibration'),
      (MethodCall methodCall) async => true,
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('StudyReminder Model Tests', () {
    test('Default values and full construction', () {
      final reminder = StudyReminder(
        id: 101,
        title: 'Morning Audit Practice',
        hour: 7,
        minute: 30,
        enabled: true,
        recurrence: ReminderRecurrence.daily,
        vibrationPattern: ReminderVibrationPattern.heartbeat,
        soundEnabled: true,
        vibrationEnabled: true,
        subjectName: 'Advanced Auditing',
      );

      expect(reminder.id, 101);
      expect(reminder.title, 'Morning Audit Practice');
      expect(reminder.hour, 7);
      expect(reminder.minute, 30);
      expect(reminder.recurrence, ReminderRecurrence.daily);
      expect(reminder.vibrationPattern, ReminderVibrationPattern.heartbeat);
      expect(reminder.soundEnabled, isTrue);
      expect(reminder.vibrationEnabled, isTrue);
      expect(reminder.subjectName, 'Advanced Auditing');
    });

    test('JSON serialization & deserialization roundtrip', () {
      final original = StudyReminder(
        id: 202,
        title: 'Taxation Revision',
        hour: 18,
        minute: 45,
        enabled: false,
        recurrence: ReminderRecurrence.weekdays,
        vibrationPattern: ReminderVibrationPattern.rapid,
        soundEnabled: false,
        vibrationEnabled: true,
        date: DateTime(2026, 11, 15),
        subjectName: 'Direct Tax Laws',
      );

      final json = original.toJson();
      expect(json['id'], 202);
      expect(json['title'], 'Taxation Revision');
      expect(json['recurrence'], 'weekdays');
      expect(json['vibrationPattern'], 'rapid');
      expect(json['soundEnabled'], false);
      expect(json['vibrationEnabled'], true);
      expect(json['date'], '2026-11-15T00:00:00.000');
      expect(json['subjectName'], 'Direct Tax Laws');

      final reconstructed = StudyReminder.fromJson(json);
      expect(reconstructed.id, original.id);
      expect(reconstructed.title, original.title);
      expect(reconstructed.hour, original.hour);
      expect(reconstructed.minute, original.minute);
      expect(reconstructed.enabled, original.enabled);
      expect(reconstructed.recurrence, ReminderRecurrence.weekdays);
      expect(reconstructed.vibrationPattern, ReminderVibrationPattern.rapid);
      expect(reconstructed.soundEnabled, isFalse);
      expect(reconstructed.vibrationEnabled, isTrue);
      expect(reconstructed.date, DateTime(2026, 11, 15));
      expect(reconstructed.subjectName, 'Direct Tax Laws');
    });

    test('Backward compatibility with legacy JSON data', () {
      // Legacy JSON without recurrence, vibrationPattern, soundEnabled, etc.
      final legacyJson = {
        'id': 50,
        'title': 'Legacy Reminder',
        'hour': 9,
        'minute': 15,
        'enabled': true,
      };

      final reminder = StudyReminder.fromJson(legacyJson);
      expect(reminder.id, 50);
      expect(reminder.title, 'Legacy Reminder');
      expect(reminder.recurrence, ReminderRecurrence.daily);
      expect(reminder.vibrationPattern, ReminderVibrationPattern.standard);
      expect(reminder.soundEnabled, isTrue);
      expect(reminder.vibrationEnabled, isTrue);
      expect(reminder.subjectName, isNull);
    });
  });

  group('ReminderSettings & StorageService Tests', () {
    test('Default values and copyWith', () {
      const defaults = ReminderSettings();
      expect(defaults.soundEnabled, isTrue);
      expect(defaults.vibrationEnabled, isTrue);
      expect(defaults.vibrationPattern, ReminderVibrationPattern.standard);
      expect(defaults.snoozeDurationMinutes, 5);

      final modified = defaults.copyWith(
        soundEnabled: false,
        vibrationPattern: ReminderVibrationPattern.gentle,
        snoozeDurationMinutes: 10,
      );
      expect(modified.soundEnabled, isFalse);
      expect(modified.vibrationEnabled, isTrue);
      expect(modified.vibrationPattern, ReminderVibrationPattern.gentle);
      expect(modified.snoozeDurationMinutes, 10);
    });

    test('StorageService save and load ReminderSettings', () async {
      // Default initial load
      final initial = await StorageService.loadReminderSettings();
      expect(initial.soundEnabled, isTrue);
      expect(initial.vibrationEnabled, isTrue);
      expect(initial.snoozeDurationMinutes, 5);

      // Save custom settings
      const custom = ReminderSettings(
        soundEnabled: false,
        vibrationEnabled: true,
        vibrationPattern: ReminderVibrationPattern.rapid,
        snoozeDurationMinutes: 15,
      );
      await StorageService.saveReminderSettings(custom);

      // Verify loaded matches custom
      final loaded = await StorageService.loadReminderSettings();
      expect(loaded.soundEnabled, isFalse);
      expect(loaded.vibrationEnabled, isTrue);
      expect(loaded.vibrationPattern, ReminderVibrationPattern.rapid);
      expect(loaded.snoozeDurationMinutes, 15);

      // Clear all data resets settings to defaults
      await StorageService.clearAllData();
      final afterClear = await StorageService.loadReminderSettings();
      expect(afterClear.soundEnabled, isTrue);
      expect(afterClear.snoozeDurationMinutes, 5);
    });
  });

  group('AlarmService Logic Tests', () {
    test('Vibration pattern intervals are correctly defined', () {
      final standard =
          AlarmService.getPatternIntervals(ReminderVibrationPattern.standard);
      expect(standard, [0, 500, 500, 500, 500]);

      final heartbeat =
          AlarmService.getPatternIntervals(ReminderVibrationPattern.heartbeat);
      expect(heartbeat, [0, 150, 100, 150, 600]);

      final rapid =
          AlarmService.getPatternIntervals(ReminderVibrationPattern.rapid);
      expect(rapid, [0, 200, 100, 200, 100]);

      final gentle =
          AlarmService.getPatternIntervals(ReminderVibrationPattern.gentle);
      expect(gentle, [0, 800, 800, 800, 800]);
    });

    test('Active alarm state triggers and stops', () async {
      final reminder = StudyReminder(
        id: 777,
        title: 'Costing Class Reminder',
        hour: 14,
        minute: 0,
        enabled: true,
      );

      expect(AlarmService.activeAlarmNotifier.value, isNull);

      // Manually set or trigger
      AlarmService.activeAlarmNotifier.value = ActiveAlarmState(
        reminder: reminder,
        triggeredAt: DateTime.now(),
        snoozeMinutes: 5,
      );

      expect(AlarmService.activeAlarmNotifier.value, isNotNull);
      expect(AlarmService.activeAlarmNotifier.value!.reminder.title,
          'Costing Class Reminder');

      // Stop alarm clears notifier
      await AlarmService.stopAlarm();
      expect(AlarmService.activeAlarmNotifier.value, isNull);
    });
  });

  group('ActiveAlarmDialog Widget Tests', () {
    testWidgets(
        'Renders alarm dialog with title, subject, time, and action buttons',
        (tester) async {
      final reminder = StudyReminder(
        id: 888,
        title: 'Strategic Management Flashcards',
        hour: 20,
        minute: 15,
        enabled: true,
        subjectName: 'Strategic Management',
      );

      final alarmState = ActiveAlarmState(
        reminder: reminder,
        triggeredAt: DateTime.now(),
        snoozeMinutes: 5,
      );

      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(isDark: false),
          home: Scaffold(
            body: ActiveAlarmDialog(
              alarmState: alarmState,
              onDismiss: () {
                dismissed = true;
              },
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Check text rendering
      expect(find.text('Study Reminder! ⏰'), findsOneWidget);
      expect(find.text('Strategic Management Flashcards'), findsOneWidget);
      expect(find.text('📚 Strategic Management'), findsOneWidget);
      expect(find.text('20:15'), findsOneWidget);
      expect(find.text('Snooze (5m)'), findsOneWidget);
      expect(find.text('Stop Alarm'), findsOneWidget);

      // Tap Stop Alarm
      await tester.tap(find.text('Stop Alarm'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(dismissed, isTrue);
    });
  });

  group('RemindersScreen UI Tests', () {
    testWidgets(
        'Renders Settings Card with Alarm Sound, Vibration switches and test buttons',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final plan = StudyPlan(
        id: 'plan-1',
        title: 'CA Intermediate May 2027',
        primaryTargetDate: DateTime(2027, 5, 2),
        reminders: [
          StudyReminder(
            id: 1,
            title: 'Evening Tax Practice',
            hour: 19,
            minute: 0,
            enabled: true,
            recurrence: ReminderRecurrence.daily,
            subjectName: 'Direct Tax',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(isDark: false),
          home: RemindersScreen(
            plan: plan,
            onSave: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Header & Section titles
      expect(find.text('Reminders & Alarms'), findsOneWidget);
      expect(find.text('Alarm & Vibration Preferences'), findsOneWidget);
      expect(find.text('Alarm Sound'), findsOneWidget);
      expect(find.text('Vibration'), findsOneWidget);
      expect(find.text('Vibration Pattern'), findsOneWidget);
      expect(find.text('Snooze Duration'), findsOneWidget);
      expect(find.text('Test Sound'), findsOneWidget);
      expect(find.text('Test Vibration'), findsOneWidget);

      // Check existing reminder item
      expect(find.text('Evening Tax Practice'), findsOneWidget);
      expect(find.text('• Direct Tax'), findsOneWidget);

      // Check Add Alert button
      expect(find.text('Add Alert'), findsOneWidget);
    });
  });
}

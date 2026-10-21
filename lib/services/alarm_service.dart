import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import '../models/study_plan.dart';
import 'storage_service.dart';

class ActiveAlarmState {
  final StudyReminder reminder;
  final DateTime triggeredAt;
  final int snoozeMinutes;

  const ActiveAlarmState({
    required this.reminder,
    required this.triggeredAt,
    this.snoozeMinutes = 5,
  });
}

class AlarmService {
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static bool _isPlayingSound = false;
  static bool _isVibrating = false;
  static Timer? _hapticTimer;

  static final ValueNotifier<ActiveAlarmState?> activeAlarmNotifier =
      ValueNotifier<ActiveAlarmState?>(null);

  /// Get the vibration duration/pause list for a pattern
  static List<int> getPatternIntervals(ReminderVibrationPattern pattern) {
    switch (pattern) {
      case ReminderVibrationPattern.heartbeat:
        return [0, 150, 100, 150, 600];
      case ReminderVibrationPattern.rapid:
        return [0, 200, 100, 200, 100];
      case ReminderVibrationPattern.gentle:
        return [0, 800, 800, 800, 800];
      case ReminderVibrationPattern.standard:
        return [0, 500, 500, 500, 500];
    }
  }

  /// Trigger an active alarm for the given reminder
  static Future<void> triggerAlarm(StudyReminder reminder) async {
    final settings = await StorageService.loadReminderSettings();

    activeAlarmNotifier.value = ActiveAlarmState(
      reminder: reminder,
      triggeredAt: DateTime.now(),
      snoozeMinutes: settings.snoozeDurationMinutes,
    );

    // 1. Trigger Sound if enabled
    if (settings.soundEnabled && reminder.soundEnabled) {
      await startAlarmSound();
    }

    // 2. Trigger Vibration if enabled
    if (settings.vibrationEnabled && reminder.vibrationEnabled) {
      final pattern = reminder.vibrationPattern;
      await startRepeatingVibration(pattern: pattern);
    }
  }

  /// Start playing the alarm ringtone in a continuous loop
  static Future<void> startAlarmSound() async {
    if (_isPlayingSound) return;
    try {
      _isPlayingSound = true;
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('audio/study_alarm.wav'));
    } catch (e) {
      debugPrint('Alarm sound play notice: $e');
    }
  }

  /// Stop playing the alarm sound immediately
  static Future<void> stopAlarmSound() async {
    _isPlayingSound = false;
    try {
      await _audioPlayer.stop();
    } catch (_) {}
  }

  /// Start repeating device vibration according to chosen pattern
  static Future<void> startRepeatingVibration({
    ReminderVibrationPattern pattern = ReminderVibrationPattern.standard,
  }) async {
    if (_isVibrating) return;
    _isVibrating = true;

    try {
      final hasVibrator = !kIsWeb && await Vibration.hasVibrator();
      if (hasVibrator) {
        final intervals = getPatternIntervals(pattern);
        await Vibration.vibrate(
          pattern: intervals,
          repeat: 0, // repeat indefinitely from index 0
        );
        return;
      }
    } catch (e) {
      debugPrint('Vibration plugin notice: $e');
    }

    // Fallback: periodic haptic feedback
    _hapticTimer?.cancel();
    _hapticTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) {
      if (!_isVibrating) {
        _hapticTimer?.cancel();
        return;
      }
      HapticFeedback.heavyImpact();
    });
    HapticFeedback.heavyImpact();
  }

  /// Stop vibration immediately
  static Future<void> stopVibration() async {
    _isVibrating = false;
    _hapticTimer?.cancel();
    _hapticTimer = null;
    try {
      if (!kIsWeb) {
        await Vibration.cancel();
      }
    } catch (_) {}
  }

  /// Stop active alarm (sound + vibration + clear state)
  static Future<void> stopAlarm() async {
    await stopAlarmSound();
    await stopVibration();
    activeAlarmNotifier.value = null;
  }

  /// Snooze active alarm for [minutes]
  static Future<void> snoozeAlarm([int? minutes]) async {
    final state = activeAlarmNotifier.value;
    await stopAlarmSound();
    await stopVibration();
    activeAlarmNotifier.value = null;

    if (state != null) {
      final snoozeDur = minutes ?? state.snoozeMinutes;
      // Reschedule one-time snooze alert in the future
      final snoozeReminder = StudyReminder(
        id: (state.reminder.id + 999999).remainder(2147483647),
        title: '${state.reminder.title} (Snoozed)',
        hour: DateTime.now().add(Duration(minutes: snoozeDur)).hour,
        minute: DateTime.now().add(Duration(minutes: snoozeDur)).minute,
        enabled: true,
        recurrence: ReminderRecurrence.none,
        subjectName: state.reminder.subjectName,
        soundEnabled: state.reminder.soundEnabled,
        vibrationEnabled: state.reminder.vibrationEnabled,
        vibrationPattern: state.reminder.vibrationPattern,
      );

      // In-app delayed trigger
      Timer(Duration(minutes: snoozeDur), () {
        triggerAlarm(snoozeReminder);
      });
    }
  }

  /// Test Sound preview (plays single cycle, non-looping)
  static Future<void> testSound() async {
    try {
      await stopAlarmSound();
      final testPlayer = AudioPlayer();
      await testPlayer.setReleaseMode(ReleaseMode.stop);
      await testPlayer.play(AssetSource('audio/study_alarm.wav'));
    } catch (e) {
      debugPrint('Test sound notice: $e');
    }
  }

  /// Test Vibration preview (plays single cycle and stops)
  static Future<void> testVibration([
    ReminderVibrationPattern pattern = ReminderVibrationPattern.standard,
  ]) async {
    try {
      final hasVibrator = !kIsWeb && await Vibration.hasVibrator();
      if (hasVibrator) {
        final intervals = getPatternIntervals(pattern);
        await Vibration.vibrate(pattern: intervals);
        return;
      }
    } catch (_) {}

    // Fallback: haptic impacts
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 200));
    HapticFeedback.mediumImpact();
  }
}

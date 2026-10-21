import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/study_plan.dart';
import '../services/alarm_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class RemindersScreen extends StatefulWidget {
  final StudyPlan plan;
  final Future<void> Function() onSave;

  const RemindersScreen({
    super.key,
    required this.plan,
    required this.onSave,
  });

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  StudyPlan get plan => widget.plan;
  ReminderSettings _settings = const ReminderSettings();
  bool _isLoadingSettings = true;
  int? _testCountdown;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final s = await StorageService.loadReminderSettings();
    if (mounted) {
      setState(() {
        _settings = s;
        _isLoadingSettings = false;
      });
    }
  }

  Future<void> _updateSettings(ReminderSettings newSettings) async {
    setState(() => _settings = newSettings);
    await StorageService.saveReminderSettings(newSettings);
  }

  void _startQuickTestCountdown() {
    if (_testCountdown != null) return;
    setState(() => _testCountdown = 3);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_testCountdown! > 1) {
        setState(() => _testCountdown = _testCountdown! - 1);
      } else {
        timer.cancel();
        setState(() => _testCountdown = null);
        final testReminder = StudyReminder(
          id: 88888,
          title: 'Quick Test Reminder',
          hour: DateTime.now().hour,
          minute: DateTime.now().minute,
          enabled: true,
          subjectName:
              plan.subjects.isNotEmpty ? plan.subjects.first.name : null,
          soundEnabled: _settings.soundEnabled,
          vibrationEnabled: _settings.vibrationEnabled,
          vibrationPattern: _settings.vibrationPattern,
        );
        AlarmService.triggerAlarm(testReminder);
      }
    });
  }

  Future<void> _addReminderDialog({StudyReminder? existing}) async {
    final titleCtrl = TextEditingController(
      text: existing?.title ?? 'Daily Study Session',
    );
    TimeOfDay selectedTime = existing != null
        ? TimeOfDay(hour: existing.hour, minute: existing.minute)
        : const TimeOfDay(hour: 18, minute: 0);

    ReminderRecurrence recurrence =
        existing?.recurrence ?? ReminderRecurrence.daily;
    DateTime? selectedDate = existing?.date ?? DateTime.now();
    String? selectedSubject = existing?.subjectName ??
        (plan.subjects.isNotEmpty ? plan.subjects.first.name : null);
    bool soundEnabled = existing?.soundEnabled ?? _settings.soundEnabled;
    bool vibrationEnabled =
        existing?.vibrationEnabled ?? _settings.vibrationEnabled;
    ReminderVibrationPattern pattern =
        existing?.vibrationPattern ?? _settings.vibrationPattern;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.pastelPurple,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.alarm_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  existing == null ? 'Schedule Reminder' : 'Edit Reminder',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Reminder Title',
                      hintText: 'e.g. Evening Revision, Morning Focus',
                    ),
                    autofocus: existing == null,
                  ),
                  const SizedBox(height: 14),

                  // Associated Subject Dropdown (Optional)
                  if (plan.subjects.isNotEmpty) ...[
                    DropdownButtonFormField<String?>(
                      initialValue:
                          plan.subjects.any((s) => s.name == selectedSubject)
                              ? selectedSubject
                              : null,
                      decoration: const InputDecoration(
                        labelText: 'Associated Subject (Optional)',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('General Study (No subject)'),
                        ),
                        ...plan.subjects.map((s) => DropdownMenuItem<String?>(
                              value: s.name,
                              child: Text(s.name),
                            )),
                      ],
                      onChanged: (val) => setD(() => selectedSubject = val),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Time Picker Button
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: ctx,
                        initialTime: selectedTime,
                      );
                      if (picked != null) setD(() => selectedTime = picked);
                    },
                    icon: const Icon(Icons.access_time_rounded),
                    label: Text(
                      'Time: ${selectedTime.format(ctx)}',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Recurrence Selection
                  Text(
                    'Repeat Schedule',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : const Color(0xFF15123A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<ReminderRecurrence>(
                    initialValue: recurrence,
                    decoration: const InputDecoration(
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: ReminderRecurrence.daily,
                        child: Text('Every Day (Daily)'),
                      ),
                      DropdownMenuItem(
                        value: ReminderRecurrence.weekdays,
                        child: Text('Weekdays (Mon – Fri)'),
                      ),
                      DropdownMenuItem(
                        value: ReminderRecurrence.weekly,
                        child: Text('Once a Week (Weekly)'),
                      ),
                      DropdownMenuItem(
                        value: ReminderRecurrence.none,
                        child: Text('Once (Specific Date)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setD(() => recurrence = val);
                    },
                  ),

                  // Date picker if recurrence == none
                  if (recurrence == ReminderRecurrence.none) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate ?? now,
                          firstDate: now,
                          lastDate: now.add(const Duration(days: 365)),
                        );
                        if (picked != null) setD(() => selectedDate = picked);
                      },
                      icon: const Icon(Icons.calendar_month_rounded, size: 18),
                      label: Text(
                        selectedDate == null
                            ? 'Select Date'
                            : DateFormat('EEE, d MMM yyyy')
                                .format(selectedDate!),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Sound & Vibration Toggles
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Audible Alarm / Sound'),
                    subtitle: const Text('Play chime when reminder triggers'),
                    value: soundEnabled,
                    activeThumbColor: AppColors.primary,
                    onChanged: (v) => setD(() => soundEnabled = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Vibration Alert'),
                    subtitle: const Text('Repeating haptic vibration'),
                    value: vibrationEnabled,
                    activeThumbColor: AppColors.primary,
                    onChanged: (v) => setD(() => vibrationEnabled = v),
                  ),

                  if (vibrationEnabled) ...[
                    const SizedBox(height: 6),
                    DropdownButtonFormField<ReminderVibrationPattern>(
                      initialValue: pattern,
                      isDense: true,
                      decoration: const InputDecoration(
                        labelText: 'Vibration Style',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: ReminderVibrationPattern.standard,
                          child: Text('Standard Pulse (500ms)'),
                        ),
                        DropdownMenuItem(
                          value: ReminderVibrationPattern.heartbeat,
                          child: Text('Heartbeat Pulse'),
                        ),
                        DropdownMenuItem(
                          value: ReminderVibrationPattern.rapid,
                          child: Text('Rapid Urgent Alert'),
                        ),
                        DropdownMenuItem(
                          value: ReminderVibrationPattern.gentle,
                          child: Text('Gentle Long Wave'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setD(() => pattern = v);
                      },
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(existing == null ? 'Schedule' : 'Save'),
              ),
            ],
          );
        },
      ),
    );

    if (ok == true && titleCtrl.text.trim().isNotEmpty) {
      if (existing != null) {
        existing.title = titleCtrl.text.trim();
        existing.hour = selectedTime.hour;
        existing.minute = selectedTime.minute;
        existing.recurrence = recurrence;
        existing.date = selectedDate;
        existing.subjectName = selectedSubject;
        existing.soundEnabled = soundEnabled;
        existing.vibrationEnabled = vibrationEnabled;
        existing.vibrationPattern = pattern;

        // Cancel previous schedule and reschedule
        await NotificationService.cancelReminder(existing.id);
        if (existing.enabled) {
          await NotificationService.scheduleReminder(existing);
        }
      } else {
        final reminder = StudyReminder(
          id: DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
          title: titleCtrl.text.trim(),
          hour: selectedTime.hour,
          minute: selectedTime.minute,
          enabled: true,
          recurrence: recurrence,
          date: selectedDate,
          subjectName: selectedSubject,
          soundEnabled: soundEnabled,
          vibrationEnabled: vibrationEnabled,
          vibrationPattern: pattern,
        );

        plan.reminders.add(reminder);
        await NotificationService.scheduleReminder(reminder);
      }

      await widget.onSave();
      if (mounted) setState(() {});
    }
  }

  Future<void> _toggleReminder(StudyReminder r, bool val) async {
    r.enabled = val;
    if (val) {
      await NotificationService.scheduleReminder(r);
    } else {
      await NotificationService.cancelReminder(r.id);
    }
    await widget.onSave();
    if (mounted) setState(() {});
  }

  Future<void> _deleteReminder(StudyReminder r) async {
    await NotificationService.cancelReminder(r.id);
    plan.reminders.remove(r);
    await widget.onSave();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeReminders = plan.reminders.where((r) => r.enabled).toList();
    final inactiveReminders = plan.reminders.where((r) => !r.enabled).toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      appBar: AppBar(
        title: Text(
          'Reminders & Alarms',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.alarm_add_rounded),
            tooltip: 'Add Reminder',
            onPressed: () => _addReminderDialog(),
          ),
        ],
      ),
      body: _isLoadingSettings
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              children: [
                // 1. Global Alert & Vibration Settings Card
                _buildSettingsCard(isDark),
                const SizedBox(height: 16),

                // 2. Platform Capability & Permissions Banner
                _buildPlatformCapabilityCard(isDark),
                const SizedBox(height: 20),

                // 3. Active Reminders Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Active Reminders (${activeReminders.length})',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : const Color(0xFF15123A),
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => _addReminderDialog(),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Add Alert'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryLight,
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        textStyle: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Active List or Empty State
                if (activeReminders.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.cardDark : AppColors.cardLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? AppColors.borderDark
                            : AppColors.borderLight,
                        width: 1.2,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.alarm_rounded,
                              size: 36,
                              color: isDark
                                  ? const Color(0xFF5A5480)
                                  : const Color(0xFFAFA7D2)),
                          const SizedBox(height: 10),
                          Text(
                            'No active study reminders.',
                            style: GoogleFonts.poppins(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap "+ Add Alert" above to schedule an audible study reminder.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: isDark
                                  ? const Color(0xFF7B759D)
                                  : const Color(0xFF8C86A8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...activeReminders.map((r) => _buildReminderCard(r, isDark)),

                // Inactive Reminders
                if (inactiveReminders.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Inactive (${inactiveReminders.length})',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...inactiveReminders
                      .map((r) => _buildReminderCard(r, isDark)),
                ],
              ],
            ),
    );
  }

  // ==========================================
  // SETTINGS CARD (SOUND, VIBRATION, TEST BUTTONS)
  // ==========================================
  Widget _buildSettingsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.borderDark : const Color(0xFFECE7F6),
          width: 1.2,
        ),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2E2958)
                      : const Color(0xFFF1ECFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alarm & Vibration Preferences',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : const Color(0xFF15123A),
                      ),
                    ),
                    Text(
                      'Customize audible alerts, haptic pulses, and snooze',
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : const Color(0xFF787295),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Toggles: Sound & Vibration
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    'Alarm Sound',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: const Text('Play audible ringtone chime'),
                  value: _settings.soundEnabled,
                  activeThumbColor: AppColors.primary,
                  onChanged: (val) {
                    _updateSettings(_settings.copyWith(soundEnabled: val));
                  },
                ),
              ),
              Expanded(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    'Vibration',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: const Text('Repeating haptic pulses'),
                  value: _settings.vibrationEnabled,
                  activeThumbColor: AppColors.primary,
                  onChanged: (val) {
                    _updateSettings(_settings.copyWith(vibrationEnabled: val));
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Vibration Pattern & Snooze Duration Row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vibration Pattern',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : const Color(0xFF6B658A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<ReminderVibrationPattern>(
                      initialValue: _settings.vibrationPattern,
                      isDense: true,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: ReminderVibrationPattern.standard,
                          child: Text('Standard Pulse'),
                        ),
                        DropdownMenuItem(
                          value: ReminderVibrationPattern.heartbeat,
                          child: Text('Heartbeat (Double)'),
                        ),
                        DropdownMenuItem(
                          value: ReminderVibrationPattern.rapid,
                          child: Text('Rapid Alert'),
                        ),
                        DropdownMenuItem(
                          value: ReminderVibrationPattern.gentle,
                          child: Text('Gentle Long Wave'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          _updateSettings(
                              _settings.copyWith(vibrationPattern: val));
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Snooze Duration',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : const Color(0xFF6B658A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      initialValue: _settings.snoozeDurationMinutes,
                      isDense: true,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 5, child: Text('5 minutes')),
                        DropdownMenuItem(value: 10, child: Text('10 minutes')),
                        DropdownMenuItem(value: 15, child: Text('15 minutes')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          _updateSettings(
                              _settings.copyWith(snoozeDurationMinutes: val));
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Interactive Test Action Buttons
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => AlarmService.testSound(),
                icon: const Icon(Icons.volume_up_rounded, size: 16),
                label: const Text('Test Sound'),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    AlarmService.testVibration(_settings.vibrationPattern),
                icon: const Icon(Icons.vibration_rounded, size: 16),
                label: const Text('Test Vibration'),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: _startQuickTestCountdown,
                icon: const Icon(Icons.play_circle_outline_rounded, size: 16),
                label: Text(
                  _testCountdown != null
                      ? 'Firing in ${_testCountdown}s...'
                      : 'Test Alarm (3s)',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // PLATFORM CAPABILITY & PERMISSIONS CARD
  // ==========================================
  Widget _buildPlatformCapabilityCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1832) : const Color(0xFFF3F0FA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF322C56) : const Color(0xFFE4DCF5),
          width: 1.1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.pastelBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.info_outline_rounded,
                color: AppColors.pastelBlueText, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kIsWeb
                      ? 'Web Platform Notice'
                      : 'Android Background Alarms Enabled',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : const Color(0xFF15123A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  kIsWeb
                      ? 'Web browsers cannot trigger background device vibration or alarm sounds when the browser tab is closed due to browser security restrictions. For persistent device alarms, run the native Android app.'
                      : 'Alarms are scheduled using Android AlarmManager with high-priority audio, repeating vibration, and wake-lock. Ensure battery optimization permits alerts for Study Tracker.',
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    height: 1.4,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // REMINDER CARD WIDGET
  // ==========================================
  Widget _buildReminderCard(StudyReminder r, bool isDark) {
    final time = TimeOfDay(hour: r.hour, minute: r.minute).format(context);

    String recurrenceLabel = 'Daily';
    switch (r.recurrence) {
      case ReminderRecurrence.daily:
        recurrenceLabel = 'Daily';
        break;
      case ReminderRecurrence.weekdays:
        recurrenceLabel = 'Mon – Fri';
        break;
      case ReminderRecurrence.weekly:
        recurrenceLabel = 'Weekly';
        break;
      case ReminderRecurrence.none:
        recurrenceLabel =
            r.date != null ? DateFormat('d MMM').format(r.date!) : 'Once';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 1.2,
        ),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        children: [
          // Icon Container
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: r.enabled
                  ? (isDark ? const Color(0xFF2E2958) : AppColors.pastelPurple)
                  : (isDark
                      ? const Color(0xFF232238)
                      : const Color(0xFFF1F1F5)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              r.enabled ? Icons.alarm_on_rounded : Icons.alarm_off_rounded,
              color: r.enabled ? AppColors.primary : Colors.grey,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),

          // Title, Time, and Badges
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        r.title,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: r.enabled
                              ? (isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight)
                              : (isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Recurrence Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: r.enabled
                            ? (isDark
                                ? const Color(0xFF2F295B)
                                : const Color(0xFFF0ECFB))
                            : (isDark
                                ? const Color(0xFF28253E)
                                : const Color(0xFFEBEBF0)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        recurrenceLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: r.enabled ? AppColors.primary : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      time,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: r.enabled ? AppColors.primary : Colors.grey,
                      ),
                    ),
                    if (r.subjectName != null && r.subjectName!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        '• ${r.subjectName!}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    // Audio & Vibration indicators
                    if (r.soundEnabled)
                      const Icon(Icons.volume_up_rounded,
                          size: 13, color: Color(0xFF9E97C2)),
                    if (r.vibrationEnabled) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.vibration_rounded,
                          size: 13, color: Color(0xFF9E97C2)),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Actions: Edit, Delete, Switch
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: 'Edit',
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
            onPressed: () => _addReminderDialog(existing: r),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            tooltip: 'Delete',
            color: AppColors.danger,
            onPressed: () => _deleteReminder(r),
          ),
          Switch(
            value: r.enabled,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primaryLight,
            onChanged: (val) => _toggleReminder(r, val),
          ),
        ],
      ),
    );
  }
}

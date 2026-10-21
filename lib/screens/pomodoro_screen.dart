import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/study_plan.dart';
import '../theme/app_theme.dart';

class PomodoroScreen extends StatefulWidget {
  final StudyPlan plan;
  final Future<void> Function() onSave;

  const PomodoroScreen({
    super.key,
    required this.plan,
    required this.onSave,
  });

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen> {
  // Timer State
  int _selectedDurationMinutes = 25;
  int _secondsRemaining = 25 * 60;
  bool _isRunning = false;
  Timer? _timer;
  DateTime? _targetEndTime;
  String _mode = 'Focus'; // 'Focus', 'Short Break', 'Long Break'

  // Subject & Task tagging
  String? _selectedSubjectId;
  final TextEditingController _taskCtrl = TextEditingController();

  // Guard against duplicate session logging
  bool _isSessionLogged = false;

  StudyPlan get plan => widget.plan;

  @override
  void initState() {
    super.initState();
    if (plan.subjects.isNotEmpty) {
      _selectedSubjectId = plan.subjects.first.id;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _taskCtrl.dispose();
    super.dispose();
  }

  void _switchMode(String mode, int minutes) {
    _timer?.cancel();
    setState(() {
      _mode = mode;
      _selectedDurationMinutes = minutes;
      _secondsRemaining = minutes * 60;
      _isRunning = false;
      _targetEndTime = null;
      _isSessionLogged = false;
    });
  }

  void _toggleTimer() {
    if (_isRunning) {
      // Pause
      _timer?.cancel();
      setState(() {
        _isRunning = false;
        _targetEndTime = null;
      });
    } else {
      // Start or Resume
      setState(() {
        _isRunning = true;
        _targetEndTime =
            DateTime.now().add(Duration(seconds: _secondsRemaining));
      });

      _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (!mounted || !_isRunning) return;

        if (_targetEndTime != null) {
          final diff = _targetEndTime!.difference(DateTime.now()).inSeconds;
          if (diff <= 0) {
            _timer?.cancel();
            setState(() {
              _secondsRemaining = 0;
              _isRunning = false;
              _targetEndTime = null;
            });
            _onTimerComplete();
          } else {
            setState(() {
              _secondsRemaining = diff;
            });
          }
        }
      });
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _targetEndTime = null;
      _secondsRemaining = _selectedDurationMinutes * 60;
      _isSessionLogged = false;
    });
  }

  Future<void> _finishAndLogEarly() async {
    final elapsedSec = (_selectedDurationMinutes * 60) - _secondsRemaining;
    final elapsedMins = (elapsedSec / 60).round();

    if (elapsedMins < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Study for at least 1 minute to log a session.')),
      );
      return;
    }

    await _logCurrentSession(elapsedMins);
    _resetTimer();
  }

  Future<void> _onTimerComplete() async {
    if (_mode == 'Focus') {
      await _logCurrentSession(_selectedDurationMinutes);

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.pastelMint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.check_circle_rounded,
                      color: AppColors.pastelMintText, size: 24),
                ),
                const SizedBox(width: 12),
                Text('Session Complete! 🎉',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: Text(
              'Amazing work! You completed $_selectedDurationMinutes minutes of focused study. Time for a refreshing break.',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _switchMode('Short Break', 15);
                },
                child: const Text('Start 15m Break'),
              ),
            ],
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Break finished! Ready to focus again?')),
        );
        _switchMode('Focus', 25);
      }
    }
  }

  Future<void> _logCurrentSession(int minutesToLog) async {
    if (_isSessionLogged) return; // Anti-duplicate guard
    _isSessionLogged = true;

    final subject = plan.subjects.firstWhere(
      (s) => s.id == _selectedSubjectId,
      orElse: () => Subject(id: 'general', name: 'General Study', total: 0),
    );

    final topic = _taskCtrl.text.trim();
    final session = StudySession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      subjectId: subject.id,
      subjectName: subject.name,
      minutes: minutesToLog,
      topic: topic.isNotEmpty ? topic : 'Focus Session',
      type: 'Pomodoro',
    );

    plan.sessions.insert(0, session);
    await widget.onSave();
    if (mounted) setState(() {});
  }

  // Dialog to enter custom focus duration
  Future<void> _showCustomDurationDialog() async {
    final ctrl = TextEditingController(text: '$_selectedDurationMinutes');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Custom Focus Duration'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Duration in Minutes',
            hintText: 'e.g. 35, 75, 90',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Apply')),
        ],
      ),
    );

    if (ok == true) {
      final mins = int.tryParse(ctrl.text.trim());
      if (mins != null && mins > 0 && mins <= 360) {
        _switchMode('Focus', mins);
      }
    }
  }

  // Dialog for manual historical session logging
  Future<void> _showManualLogDialog() async {
    final minsCtrl = TextEditingController(text: '45');
    final topicCtrl = TextEditingController();
    String? subjectId = _selectedSubjectId ??
        (plan.subjects.isNotEmpty ? plan.subjects.first.id : null);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Text('Log Study Session'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (plan.subjects.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: subjectId,
                  decoration: const InputDecoration(labelText: 'Subject'),
                  items: plan.subjects.map((s) {
                    return DropdownMenuItem(value: s.id, child: Text(s.name));
                  }).toList(),
                  onChanged: (v) => setD(() => subjectId = v),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: minsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Minutes Studied', hintText: 'e.g. 60'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: topicCtrl,
                decoration: const InputDecoration(
                    labelText: 'Topic Studied (Optional)',
                    hintText: 'e.g. Chapter 4 Practice'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Log Session')),
          ],
        ),
      ),
    );

    if (ok == true) {
      final mins = int.tryParse(minsCtrl.text.trim()) ?? 30;
      final subject = plan.subjects.firstWhere(
        (s) => s.id == subjectId,
        orElse: () => Subject(id: 'gen', name: 'General Study', total: 0),
      );

      final session = StudySession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        subjectId: subject.id,
        subjectName: subject.name,
        minutes: mins,
        topic: topicCtrl.text.trim().isNotEmpty
            ? topicCtrl.text.trim()
            : 'Self Study',
        type: 'Manual',
      );

      plan.sessions.insert(0, session);
      await widget.onSave();
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalSec = _selectedDurationMinutes * 60;
    final progress = totalSec == 0
        ? 0.0
        : ((totalSec - _secondsRemaining) / totalSec).clamp(0.0, 1.0);

    final mins = _secondsRemaining ~/ 60;
    final secs = _secondsRemaining % 60;
    final timerString =
        '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    final todayMinutes = plan.todayStudyMinutes;
    final dailyGoalMinutes = plan.dailyGoalMinutes;
    final goalProgress = dailyGoalMinutes == 0
        ? 0.0
        : (todayMinutes / dailyGoalMinutes).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Focus Timer',
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                          Text(
                            'Deep work sessions with Pomodoro intervals',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                      OutlinedButton.icon(
                        onPressed: _showManualLogDialog,
                        icon: const Icon(Icons.add_task_rounded, size: 16),
                        label: const Text('Manual Log'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Today's Goal Progress Capsule
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.cardDark : AppColors.cardLight,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark
                            ? AppColors.borderDark
                            : AppColors.borderLight,
                        width: 1.2,
                      ),
                      boxShadow: AppColors.softShadow,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.pastelMint,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.timer_outlined,
                              color: AppColors.pastelMintText, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Today’s Focus: ${(todayMinutes / 60).toStringAsFixed(1)} / ${(dailyGoalMinutes / 60).toStringAsFixed(1)} hrs',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? AppColors.textPrimaryDark
                                          : AppColors.textPrimaryLight,
                                    ),
                                  ),
                                  Text(
                                    '${(goalProgress * 100).round()}%',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.pastelMintText,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: goalProgress,
                                  minHeight: 6,
                                  backgroundColor: isDark
                                      ? const Color(0xFF282645)
                                      : const Color(0xFFEDE9F8),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                          AppColors.pastelMintText),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Main Timer Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 28),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.cardDark : AppColors.cardLight,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: isDark
                            ? AppColors.borderDark
                            : AppColors.borderLight,
                        width: 1.2,
                      ),
                      boxShadow: AppColors.softShadow,
                    ),
                    child: Column(
                      children: [
                        // Mode Selector Pills (Focus / Short Break / Long Break)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF262444)
                                : AppColors.pastelPurple,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Wrap(
                            spacing: 4,
                            children: [
                              _buildModePill('Focus', 25, isDark),
                              _buildModePill('Short Break (15m)', 15, isDark),
                              _buildModePill('Long Break (30m)', 30, isDark),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Preset Duration Pills (25m, 45m, 50m, 60m, Custom)
                        if (_mode == 'Focus') ...[
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              _buildPresetPill(25, isDark),
                              _buildPresetPill(45, isDark),
                              _buildPresetPill(50, isDark),
                              _buildPresetPill(60, isDark),
                              ActionChip(
                                label: Text(
                                  _selectedDurationMinutes != 25 &&
                                          _selectedDurationMinutes != 45 &&
                                          _selectedDurationMinutes != 50 &&
                                          _selectedDurationMinutes != 60
                                      ? 'Custom: ${_selectedDurationMinutes}m'
                                      : 'Custom',
                                  style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                ),
                                avatar:
                                    const Icon(Icons.tune_rounded, size: 14),
                                onPressed: _isRunning
                                    ? null
                                    : _showCustomDurationDialog,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Big Circular Timer Display
                        SizedBox(
                          width: 230,
                          height: 230,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outer background circle
                              SizedBox(
                                width: 230,
                                height: 230,
                                child: CircularProgressIndicator(
                                  value: progress,
                                  strokeWidth: 12,
                                  backgroundColor: isDark
                                      ? const Color(0xFF282645)
                                      : const Color(0xFFEDE9F8),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _mode == 'Focus'
                                        ? AppColors.primary
                                        : (_mode.contains('Short')
                                            ? AppColors.pastelMintText
                                            : const Color(0xFF2D9CDB)),
                                  ),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    timerString,
                                    style: GoogleFonts.poppins(
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -1,
                                      color: isDark
                                          ? AppColors.textPrimaryDark
                                          : AppColors.textPrimaryLight,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF262444)
                                          : AppColors.pastelPurple,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _isRunning
                                          ? 'FOCUSING'
                                          : (_secondsRemaining == 0
                                              ? 'COMPLETED'
                                              : 'READY'),
                                      style: GoogleFonts.poppins(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.2,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Subject & Current Task Inputs
                        if (plan.subjects.isNotEmpty && _mode == 'Focus') ...[
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: Column(
                              children: [
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedSubjectId,
                                  decoration: const InputDecoration(
                                    labelText: 'Tag Subject',
                                    prefixIcon: Icon(
                                        Icons.bookmark_outline_rounded,
                                        size: 18),
                                  ),
                                  items: plan.subjects.map((s) {
                                    return DropdownMenuItem(
                                        value: s.id, child: Text(s.name));
                                  }).toList(),
                                  onChanged: _isRunning
                                      ? null
                                      : (v) => setState(
                                          () => _selectedSubjectId = v),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _taskCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'What are you working on?',
                                    hintText:
                                        'e.g. Solving practice set, Watching lecture 12',
                                    prefixIcon:
                                        Icon(Icons.edit_note_rounded, size: 18),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Main Controls Row (Start/Pause, Finish & Log, Reset)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Reset
                            IconButton.outlined(
                              icon: const Icon(Icons.replay_rounded),
                              tooltip: 'Reset',
                              onPressed: _resetTimer,
                              style: IconButton.styleFrom(
                                padding: const EdgeInsets.all(14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Start / Pause
                            FilledButton.icon(
                              onPressed: _toggleTimer,
                              icon: Icon(
                                  _isRunning
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 24),
                              label: Text(_isRunning ? 'Pause' : 'Start Focus'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 32, vertical: 16),
                                textStyle: GoogleFonts.poppins(
                                    fontSize: 15, fontWeight: FontWeight.bold),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Finish & Log Early
                            IconButton.outlined(
                              icon: const Icon(
                                  Icons.check_circle_outline_rounded),
                              tooltip: 'Finish & Log',
                              onPressed: _finishAndLogEarly,
                              style: IconButton.styleFrom(
                                padding: const EdgeInsets.all(14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Recent Sessions Section
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Recent Study Sessions',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (plan.sessions.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color:
                            isDark ? AppColors.cardDark : AppColors.cardLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? AppColors.borderDark
                              : AppColors.borderLight,
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.history_rounded,
                              size: 36, color: AppColors.textSecondaryLight),
                          const SizedBox(height: 8),
                          Text(
                            'No sessions recorded yet',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          Text(
                            'Start a timer session above to build your study history.',
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.textSecondaryLight),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: plan.sessions.take(6).length,
                      itemBuilder: (ctx, index) {
                        final s = plan.sessions[index];
                        final timeStr =
                            DateFormat('d MMM, h:mm a').format(s.timestamp);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.cardDark
                                : AppColors.cardLight,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.borderDark
                                  : AppColors.borderLight,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.pastelPurple,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.timer_rounded,
                                    size: 16, color: AppColors.primary),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.subjectName,
                                      style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13),
                                    ),
                                    if (s.topic.isNotEmpty)
                                      Text(
                                        s.topic,
                                        style: GoogleFonts.poppins(
                                          fontSize: 11.5,
                                          color: isDark
                                              ? AppColors.textSecondaryDark
                                              : AppColors.textSecondaryLight,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${s.minutes} min',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  Text(
                                    timeStr,
                                    style: GoogleFonts.poppins(
                                      fontSize: 10.5,
                                      color: isDark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModePill(String title, int minutes, bool isDark) {
    final isSelected = _mode.startsWith(title.split(' ').first);

    return InkWell(
      onTap: () => _switchMode(title, minutes),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF383362) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected ? AppColors.softShadow : null,
        ),
        child: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? AppColors.primary
                : (isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetPill(int minutes, bool isDark) {
    final isSelected = _selectedDurationMinutes == minutes;

    return ChoiceChip(
      label: Text('${minutes}m'),
      selected: isSelected,
      onSelected: _isRunning
          ? null
          : (val) {
              if (val) _switchMode('Focus', minutes);
            },
      selectedColor: AppColors.primaryLight,
      labelStyle: GoogleFonts.poppins(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected
            ? AppColors.primary
            : (isDark ? Colors.white : AppColors.textPrimaryLight),
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}

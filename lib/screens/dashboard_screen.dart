import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/study_plan.dart';
import '../theme/app_theme.dart';
import 'subject_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  final StudyPlan plan;
  final List<StudyPlan> allPlans;
  final bool isDark;
  final VoidCallback onToggleTheme;
  final Function(String planId) onSwitchPlan;
  final VoidCallback onAddSubject;
  final VoidCallback onEditPlan;
  final VoidCallback onStartTimer;
  final Future<void> Function() onSave;
  final Function(int tabIndex) onNavigateTab;
  final String? userName;

  const DashboardScreen({
    super.key,
    required this.plan,
    required this.allPlans,
    required this.isDark,
    required this.onToggleTheme,
    required this.onSwitchPlan,
    required this.onAddSubject,
    required this.onEditPlan,
    required this.onStartTimer,
    required this.onSave,
    required this.onNavigateTab,
    this.userName,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Refresh header clock every 30 seconds
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() => _currentTime = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  StudyPlan get plan => widget.plan;

  String _getGreeting() {
    final name = (widget.userName != null && widget.userName!.trim().isNotEmpty)
        ? widget.userName!.trim()
        : 'Student';
    final hour = _currentTime.hour;
    if (hour < 12) return 'Good Morning, $name ✨';
    if (hour < 17) return 'Good Afternoon, $name ✨';
    if (hour < 21) return 'Good Evening, $name ✨';
    return 'Good Night, $name ✨';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final isTablet = screenWidth >= 680 && screenWidth < 1024;

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 28 : (isTablet ? 20 : 16),
            vertical: 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. TOP HEADER (Greeting, Subtitle, Clock, Theme Toggle, Avatar)
              _buildHeader(context, isDark, isDesktop),
              const SizedBox(height: 24),

              // 2. ROW 1: PRIMARY TARGET + BACKUP TARGET + INSPIRATIONAL QUOTE
              _buildTargetRow(context, isDark, isDesktop, isTablet),
              const SizedBox(height: 20),

              // 3. ROW 2: OVERALL PROGRESS + SUBJECT-WISE PROGRESS + STUDY STREAK
              _buildStatsRow(context, isDark, isDesktop, isTablet),
              const SizedBox(height: 24),

              // 4. ROW 3: SUBJECTS SECTION (Header + Add Subject button + Subject Cards Grid)
              _buildSubjectsSection(context, isDark, isDesktop, isTablet),
              const SizedBox(height: 24),

              // 5. ROW 4: UPCOMING TASKS + QUICK ACTIONS
              _buildBottomActionsRow(context, isDark, isDesktop),
              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 1. TOP HEADER
  // ==========================================
  Widget _buildHeader(BuildContext context, bool isDark, bool isDesktop) {
    final dateStr = DateFormat('EEE, d MMM yyyy').format(_currentTime);
    final timeStr = DateFormat('h:mm a').format(_currentTime);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 640;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Greeting & Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getGreeting(),
                    style: GoogleFonts.poppins(
                      fontSize: isNarrow ? 20 : 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Plan • Track • Revise • Achieve',
                        style: GoogleFonts.poppins(
                          fontSize: isNarrow ? 12 : 14,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                      if (widget.allPlans.length > 1) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            plan.title,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Right: Date & Time Capsule + Theme Switcher + Avatar
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isNarrow) ...[
                  // Date & Time Capsule
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.cardDark : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? AppColors.borderDark
                            : AppColors.borderLight,
                        width: 1.2,
                      ),
                      boxShadow: AppColors.softShadow,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 16,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$dateStr  $timeStr',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                ],

                // Theme Mode Switcher Capsule
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onToggleTheme,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.cardDark : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? AppColors.borderDark
                              : AppColors.borderLight,
                          width: 1.2,
                        ),
                        boxShadow: AppColors.softShadow,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.wb_sunny_outlined,
                            size: 16,
                            color: !isDark
                                ? AppColors.pastelOrangeText
                                : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.nightlight_round,
                            size: 16,
                            color: isDark
                                ? const Color(0xFFA899FF)
                                : Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Plan / User Avatar with popup menu to switch plans
                PopupMenuButton<String>(
                  tooltip: 'Switch Study Plan',
                  onSelected: widget.onSwitchPlan,
                  offset: const Offset(0, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                  color: isDark ? AppColors.cardDark : Colors.white,
                  itemBuilder: (ctx) => widget.allPlans.map((p) {
                    final isCurrent = p.id == plan.id;
                    return PopupMenuItem<String>(
                      value: p.id,
                      child: Row(
                        children: [
                          Icon(
                            isCurrent
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 16,
                            color: isCurrent ? AppColors.primary : Colors.grey,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              p.title,
                              style: GoogleFonts.poppins(
                                fontWeight: isCurrent
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF3B3568)
                            : const Color(0xFFE2DCF8),
                        width: 1.5,
                      ),
                      boxShadow: AppColors.softShadow,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      plan.title.isNotEmpty ? plan.title[0].toUpperCase() : 'S',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // ==========================================
  // 2. ROW 1: PRIMARY TARGET + BACKUP + MOTIVATION
  // ==========================================
  Widget _buildTargetRow(
      BuildContext context, bool isDark, bool isDesktop, bool isTablet) {
    final primaryCard = _buildTargetCard(
      context: context,
      isDark: isDark,
      isPrimary: true,
      title: plan.primaryTargetLabel.isNotEmpty
          ? plan.primaryTargetLabel
          : 'Target Exam',
      targetDate: plan.primaryTargetDate,
      countdown: plan.primaryCountdown,
      containerColor: AppColors.pastelPink,
      iconColor: AppColors.pastelPinkText,
      icon: Icons.track_changes_rounded,
      onEdit: widget.onEditPlan,
    );

    final backupCard = _buildTargetCard(
      context: context,
      isDark: isDark,
      isPrimary: false,
      title: plan.backupTargetLabel.isNotEmpty
          ? plan.backupTargetLabel
          : 'Backup Target',
      targetDate: plan.backupTargetDate,
      countdown: plan.backupCountdown,
      containerColor: AppColors.pastelBlue,
      iconColor: AppColors.pastelBlueText,
      icon: Icons.flag_rounded,
      onEdit: widget.onEditPlan,
    );

    final motivationCard = _buildMotivationCard(context, isDark);

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 38, child: primaryCard),
          const SizedBox(width: 18),
          Expanded(flex: 38, child: backupCard),
          const SizedBox(width: 18),
          Expanded(flex: 24, child: motivationCard),
        ],
      );
    }

    if (isTablet) {
      return Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: primaryCard),
              const SizedBox(width: 16),
              Expanded(child: backupCard),
            ],
          ),
          const SizedBox(height: 16),
          motivationCard,
        ],
      );
    }

    // Mobile layout
    return Column(
      children: [
        primaryCard,
        const SizedBox(height: 16),
        backupCard,
        const SizedBox(height: 16),
        motivationCard,
      ],
    );
  }

  Widget _buildTargetCard({
    required BuildContext context,
    required bool isDark,
    required bool isPrimary,
    required String title,
    required DateTime? targetDate,
    required TargetCountdown countdown,
    required Color containerColor,
    required Color iconColor,
    required IconData icon,
    required VoidCallback onEdit,
  }) {
    final dateDisplay = targetDate != null
        ? DateFormat('d MMM yyyy').format(targetDate)
        : 'Not set';
    final progressVal =
        isPrimary ? plan.overallProgress : (plan.overallProgress * 0.75);
    final percentVal = (progressVal * 100).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 1.2,
        ),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Icon Container + Title & Date + Edit Icon
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isDark
                      ? containerColor.withValues(alpha: 0.18)
                      : containerColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPrimary ? 'Primary Target' : 'Backup Target',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onEdit,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(3),
                              child: Icon(
                                Icons.edit_rounded,
                                size: 15,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 12,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          dateDisplay,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                        if (targetDate != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: isPrimary
                                  ? AppColors.pastelPink
                                  : AppColors.pastelBlue,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Notified',
                              style: GoogleFonts.poppins(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: isPrimary
                                    ? AppColors.pastelPinkText
                                    : AppColors.pastelBlueText,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // 4 Countdown Stat Boxes
          Row(
            children: [
              Expanded(
                  child:
                      _buildCountdownBox(isDark, '${countdown.days}', 'Days')),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildCountdownBox(
                      isDark, '${countdown.months}', 'Months')),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildCountdownBox(
                      isDark, '${countdown.hours}', 'Hours')),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildCountdownBox(
                      isDark, '${countdown.minutes}', 'Minutes')),
            ],
          ),

          const SizedBox(height: 16),

          // Bottom Progress Bar & Percentage
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progressVal.clamp(0.0, 1.0),
                    minHeight: 7,
                    backgroundColor: isDark
                        ? const Color(0xFF282645)
                        : const Color(0xFFEDE9F8),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isPrimary ? AppColors.primary : const Color(0xFF2D9CDB),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$percentVal%',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color:
                      isPrimary ? AppColors.primary : const Color(0xFF2D9CDB),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownBox(bool isDark, String value, String unit) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF262444) : AppColors.pastelPurple,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF383562) : const Color(0xFFE8E2F8),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.2,
              color: isDark ? Colors.white : const Color(0xFF433099),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            unit,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMotivationCard(BuildContext context, bool isDark) {
    final pace = plan.dailyRequiredPace;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 1.2,
        ),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Stack of books with leaves illustration
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF262444) : AppColors.pastelPurple,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_stories_rounded,
              color: AppColors.primary,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '“Small steps every day lead to big results.”',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.4,
              color:
                  isDark ? AppColors.textPrimaryDark : const Color(0xFF3B2F70),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('💜', style: TextStyle(fontSize: 13)),
              if (pace > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Pace: ${pace.toStringAsFixed(1)}/day',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 3. ROW 2: STATS & CHARTS
  // ==========================================
  Widget _buildStatsRow(
      BuildContext context, bool isDark, bool isDesktop, bool isTablet) {
    final overallCard = _buildOverallProgressCard(context, isDark);
    final subjectWiseCard = _buildSubjectWiseProgressCard(context, isDark);
    final streakCard = _buildStudyStreakCard(context, isDark);

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 38, child: overallCard),
          const SizedBox(width: 18),
          Expanded(flex: 38, child: subjectWiseCard),
          const SizedBox(width: 18),
          Expanded(flex: 24, child: streakCard),
        ],
      );
    }

    if (isTablet) {
      return Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: overallCard),
              const SizedBox(width: 16),
              Expanded(child: subjectWiseCard),
            ],
          ),
          const SizedBox(height: 16),
          streakCard,
        ],
      );
    }

    // Mobile
    return Column(
      children: [
        overallCard,
        const SizedBox(height: 16),
        subjectWiseCard,
        const SizedBox(height: 16),
        streakCard,
      ],
    );
  }

  Widget _buildOverallProgressCard(BuildContext context, bool isDark) {
    final completed = plan.completedItems;
    final total = plan.totalItems;
    final pending = plan.pendingItems;
    final revisions = plan.completedRevisions;
    final selfTests = plan.selfTestsCompleted;
    final percent = plan.overallProgressPercent;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 1.2,
        ),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bar_chart_rounded,
                    size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Text(
                'Overall Progress',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Count and percentage headline
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text.rich(
                TextSpan(
                  text: '$completed / $total ',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                  children: [
                    TextSpan(
                      text: 'items completed',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$percent%',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Rounded Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: plan.overallProgress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor:
                  isDark ? const Color(0xFF282645) : const Color(0xFFEDE9F8),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 18),

          // 4 Mini Quick Stat Pills
          Row(
            children: [
              Expanded(
                child: _buildMiniStatPill(
                  isDark: isDark,
                  icon: Icons.play_arrow_rounded,
                  count: '$completed',
                  label: 'Completed',
                  bgColor: AppColors.pastelBlue,
                  fgColor: AppColors.pastelBlueText,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniStatPill(
                  isDark: isDark,
                  icon: Icons.format_list_bulleted_rounded,
                  count: '$pending',
                  label: 'Pending',
                  bgColor: AppColors.pastelPurple,
                  fgColor: AppColors.pastelPurpleText,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniStatPill(
                  isDark: isDark,
                  icon: Icons.sync_rounded,
                  count: '$revisions',
                  label: 'Revisions',
                  bgColor: AppColors.pastelPink,
                  fgColor: AppColors.pastelPinkText,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniStatPill(
                  isDark: isDark,
                  icon: Icons.description_outlined,
                  count: '$selfTests',
                  label: 'Self Tests',
                  bgColor: AppColors.pastelTeal,
                  fgColor: AppColors.pastelTealText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatPill({
    required bool isDark,
    required IconData icon,
    required String count,
    required String label,
    required Color bgColor,
    required Color fgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF262444) : bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: fgColor),
              const SizedBox(width: 3),
              Text(
                count,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : fgColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectWiseProgressCard(BuildContext context, bool isDark) {
    final completed = plan.completedItems;
    final pending = plan.pendingItems;
    final revisions = plan.completedRevisions;
    final selfTests = plan.selfTestsCompleted;
    final percent = plan.overallProgressPercent;

    final hasData = plan.subjects.isNotEmpty && (completed > 0 || pending > 0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 1.2,
        ),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Subject-wise Progress',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Circular / Donut progress chart
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 32,
                        sections: hasData
                            ? [
                                PieChartSectionData(
                                  value: completed > 0
                                      ? completed.toDouble()
                                      : 0.1,
                                  color: AppColors.primary,
                                  showTitle: false,
                                  radius: 12,
                                ),
                                PieChartSectionData(
                                  value: pending > 0 ? pending.toDouble() : 0.1,
                                  color: const Color(0xFFF59E0B),
                                  showTitle: false,
                                  radius: 12,
                                ),
                                if (revisions > 0)
                                  PieChartSectionData(
                                    value: revisions.toDouble(),
                                    color: const Color(0xFFE0567A),
                                    showTitle: false,
                                    radius: 12,
                                  ),
                                if (selfTests > 0)
                                  PieChartSectionData(
                                    value: selfTests.toDouble(),
                                    color: const Color(0xFF2D9CDB),
                                    showTitle: false,
                                    radius: 12,
                                  ),
                              ]
                            : [
                                PieChartSectionData(
                                  value: 1,
                                  color: isDark
                                      ? const Color(0xFF2B2A4A)
                                      : const Color(0xFFEDE9F8),
                                  showTitle: false,
                                  radius: 12,
                                ),
                              ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$percent%',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        Text(
                          'Completed',
                          style: GoogleFonts.poppins(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 20),

              // Legend
              Expanded(
                child: Column(
                  children: [
                    _buildLegendRow(
                        isDark, AppColors.primary, 'Completed', '$completed'),
                    const SizedBox(height: 6),
                    _buildLegendRow(
                        isDark, const Color(0xFFF59E0B), 'Pending', '$pending'),
                    const SizedBox(height: 6),
                    _buildLegendRow(isDark, const Color(0xFFE0567A),
                        'Revisions', '$revisions'),
                    const SizedBox(height: 6),
                    _buildLegendRow(isDark, const Color(0xFF2D9CDB),
                        'Self Tests', '$selfTests'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendRow(
      bool isDark, Color dotColor, String label, String value) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color:
                isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
      ],
    );
  }

  Widget _buildStudyStreakCard(BuildContext context, bool isDark) {
    final streak = plan.studyStreakDays;
    final activeWeekDays = plan.currentWeekActiveDays;
    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 1.2,
        ),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                'Study Streak',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Streak Headline + Day Pills
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$streak ${streak == 1 ? "Day" : "Days"}',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFE0567A),
                ),
              ),
              Row(
                children: List.generate(7, (i) {
                  final active = activeWeekDays.length > i && activeWeekDays[i];
                  return Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Column(
                      children: [
                        Text(
                          dayLabels[i],
                          style: GoogleFonts.poppins(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: active
                                ? AppColors.primary
                                : (isDark
                                    ? const Color(0xFF2C2A4A)
                                    : const Color(0xFFDED8F3)),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),

          const SizedBox(height: 4),
          Text(
            'Keep going! You got this ✨',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 12),

          // Mini discipline quote card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF262444) : AppColors.pastelPurple,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.eco_rounded,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Discipline today creates the freedom you want tomorrow.',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? const Color(0xFFDDD9FA)
                          : const Color(0xFF4C3D82),
                    ),
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
  // 4. ROW 3: SUBJECTS SECTION
  // ==========================================
  Widget _buildSubjectsSection(
      BuildContext context, bool isDark, bool isDesktop, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.menu_book_rounded,
                    color: AppColors.primary, size: 22),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Subjects',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    Text(
                      'Tap on a subject to manage lectures, notes, revisions and more.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // + Add Subject button
            FilledButton.icon(
              onPressed: widget.onAddSubject,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Subject'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                textStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Grid of Subject Cards
        if (plan.subjects.isEmpty)
          _buildEmptySubjectsCard(context, isDark)
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final crossAxisCount = width >= 1100 ? 4 : (width >= 650 ? 2 : 1);

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: plan.subjects.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  mainAxisExtent: 110,
                ),
                itemBuilder: (ctx, index) {
                  final s = plan.subjects[index];
                  return _buildSubjectCard(context, isDark, s, index);
                },
              );
            },
          ),
      ],
    );
  }

  Widget _buildSubjectCard(
      BuildContext context, bool isDark, Subject subject, int index) {
    final style = AppIcons.getStyleFor(subject.name, index);
    final icon = AppIcons.getIconFromCode(subject.iconCodePoint);
    final containerColor = subject.colorValue != null
        ? Color(subject.colorValue!).withValues(alpha: 0.15)
        : style.$2;
    final iconColor =
        subject.colorValue != null ? Color(subject.colorValue!) : style.$3;

    final completed = subject.effectiveCompleted;
    final total = subject.effectiveTotal;
    final percent = subject.progressPercent;
    final progress = subject.progressRatio;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => SubjectDetailScreen(
                subject: subject,
                plan: plan,
                onSave: widget.onSave,
              ),
            ),
          );
          if (mounted) setState(() {});
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
              width: 1.2,
            ),
            boxShadow: AppColors.softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top line: Icon container + Subject Name + Chevron
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDark
                          ? containerColor.withValues(alpha: 0.22)
                          : containerColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      subject.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ],
              ),

              // Bottom line: Count & Percent + Progress Bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$completed / $total lectures',
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                      Text(
                        '$percent%',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 5,
                      backgroundColor: isDark
                          ? const Color(0xFF282645)
                          : const Color(0xFFEDE9F8),
                      valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySubjectsCard(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 1.2,
        ),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.menu_book_rounded,
                color: AppColors.primary, size: 36),
          ),
          const SizedBox(height: 14),
          Text(
            'No subjects added yet',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add your exam or course subjects to track lecture progress, take notes, and plan revisions.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: widget.onAddSubject,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Your First Subject'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 5. ROW 4: UPCOMING TASKS & QUICK ACTIONS
  // ==========================================
  Widget _buildBottomActionsRow(
      BuildContext context, bool isDark, bool isDesktop) {
    final upcomingTasksCard = _buildUpcomingTasksCard(context, isDark);
    final quickActionsCard = _buildQuickActionsCard(context, isDark);

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 45, child: upcomingTasksCard),
          const SizedBox(width: 18),
          Expanded(flex: 55, child: quickActionsCard),
        ],
      );
    }

    return Column(
      children: [
        upcomingTasksCard,
        const SizedBox(height: 16),
        quickActionsCard,
      ],
    );
  }

  Widget _buildUpcomingTasksCard(BuildContext context, bool isDark) {
    final reminders = plan.reminders;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 1.2,
        ),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_outlined,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Upcoming Tasks',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (reminders.isEmpty)
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No tasks yet',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Add reminders to keep your study on track.',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF262444)
                        : AppColors.pastelPurple,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.event_note_rounded,
                    color: AppColors.primary,
                    size: 32,
                  ),
                ),
              ],
            )
          else
            Column(
              children: reminders.take(2).map((r) {
                final time =
                    TimeOfDay(hour: r.hour, minute: r.minute).format(context);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF262444)
                        : AppColors.pastelPurple,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          r.title,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                      ),
                      Text(
                        time,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 1.2,
        ),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded,
                  color: Color(0xFFE0567A), size: 20),
              const SizedBox(width: 8),
              Text(
                'Quick Actions',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 4 Action Buttons matching reference design
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              // 1. Add Subject (Solid Purple)
              FilledButton.icon(
                onPressed: widget.onAddSubject,
                icon: const Icon(Icons.menu_book_rounded, size: 16),
                label: const Text('Add Subject'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  textStyle: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 12.5),
                ),
              ),

              // 2. Explore Classes (Outline)
              OutlinedButton.icon(
                onPressed: () => widget.onNavigateTab(2),
                icon: const Icon(Icons.smart_display_rounded, size: 16),
                label: const Text('Explore Classes'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  textStyle: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500, fontSize: 12.5),
                ),
              ),

              // 3. Digital Notes (Outline)
              OutlinedButton.icon(
                onPressed: () => widget.onNavigateTab(3),
                icon: const Icon(Icons.edit_note_rounded, size: 16),
                label: const Text('Digital Notes'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  textStyle: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500, fontSize: 12.5),
                ),
              ),

              // 4. View Revision (Outline)
              OutlinedButton.icon(
                onPressed: () => widget.onNavigateTab(5),
                icon: const Icon(Icons.sync_rounded, size: 16),
                label: const Text('View Revision'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  textStyle: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500, fontSize: 12.5),
                ),
              ),

              // 5. Add Reminder (Outline)
              OutlinedButton.icon(
                onPressed: () => widget.onNavigateTab(6),
                icon: const Icon(Icons.notifications_none_rounded, size: 16),
                label: const Text('Add Reminder'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  textStyle: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500, fontSize: 12.5),
                ),
              ),

              // 6. Start Timer / Self Test (Outline)
              OutlinedButton.icon(
                onPressed: widget.onStartTimer,
                icon: const Icon(Icons.timer_rounded, size: 16),
                label: const Text('Focus Timer'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  textStyle: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500, fontSize: 12.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

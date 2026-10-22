import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/study_plan.dart';
import '../services/alarm_service.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/active_alarm_dialog.dart';
import '../widgets/sync_status_badge.dart';
import 'auth_screen.dart';
import 'dashboard_screen.dart';
import 'subjects_screen.dart';
import 'classes_hub_screen.dart';
import 'notes_library_screen.dart';
import 'pomodoro_screen.dart';
import 'revision_screen.dart';
import 'reminders_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  final List<StudyPlan> initialPlans;
  final String activePlanId;
  final bool isDark;
  final VoidCallback onToggleTheme;
  final VoidCallback onReloadAll;
  final String? userName;

  const HomeShell({
    super.key,
    required this.initialPlans,
    required this.activePlanId,
    required this.isDark,
    required this.onToggleTheme,
    required this.onReloadAll,
    this.userName,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late List<StudyPlan> _plans;
  late String _activePlanId;
  int _selectedTabIndex = 0;
  final Set<int> _loadedTabs = {0};
  bool _isShowingAlarmDialog = false;

  void _selectTab(int idx) {
    if (_selectedTabIndex != idx || !_loadedTabs.contains(idx)) {
      setState(() {
        _selectedTabIndex = idx;
        _loadedTabs.add(idx);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _plans = widget.initialPlans;
    _activePlanId = widget.activePlanId;
    AlarmService.activeAlarmNotifier.addListener(_onAlarmTriggered);
  }

  @override
  void dispose() {
    AlarmService.activeAlarmNotifier.removeListener(_onAlarmTriggered);
    super.dispose();
  }

  void _onAlarmTriggered() {
    final state = AlarmService.activeAlarmNotifier.value;
    if (state != null && mounted && !_isShowingAlarmDialog) {
      _isShowingAlarmDialog = true;
      ActiveAlarmDialog.show(context, state).then((_) {
        _isShowingAlarmDialog = false;
      });
    }
  }

  StudyPlan get _activePlan {
    return _plans.firstWhere(
      (p) => p.id == _activePlanId,
      orElse: () => _plans.isNotEmpty
          ? _plans.first
          : StudyPlan(id: 'default', title: 'My Study Plan'),
    );
  }

  Future<void> _persistAll() async {
    await StorageService.savePlans(_plans);
    await StorageService.saveActivePlanId(_activePlanId);
    if (mounted) setState(() {});
  }

  void _switchPlan(String newId) {
    setState(() {
      _activePlanId = newId;
    });
    StorageService.saveActivePlanId(newId);
  }

  Future<void> _addPlan(StudyPlan newPlan) async {
    setState(() {
      _plans.add(newPlan);
      _activePlanId = newPlan.id;
    });
    await _persistAll();
  }

  Future<void> _deletePlan(String planId) async {
    if (_plans.length <= 1) return;
    setState(() {
      _plans.removeWhere((p) => p.id == planId);
      _activePlanId = _plans.first.id;
    });
    await _persistAll();
  }

  // Quick Dialog to add a subject into the active plan
  Future<void> _showAddSubjectDialog() async {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final countCtrl = TextEditingController(text: '30');
    TrackingType type = TrackingType.flatLectures;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.pastelPurple,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add_box_rounded,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Add Subject / Course',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Subject Name',
                    hintText: 'e.g. Corporate Law, Microeconomics, Biology',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Code / Tag (Optional)',
                    hintText: 'e.g. LAW-201, Paper 1, Unit 3',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<TrackingType>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Tracking Mode'),
                  items: const [
                    DropdownMenuItem(
                      value: TrackingType.flatLectures,
                      child: Text('Lecture Counter (1..N)'),
                    ),
                    DropdownMenuItem(
                      value: TrackingType.chapters,
                      child: Text('Chapters & Subtopics'),
                    ),
                    DropdownMenuItem(
                      value: TrackingType.tasks,
                      child: Text('Task Checklist'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setD(() => type = v);
                  },
                ),
                if (type == TrackingType.flatLectures) ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: countCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Total Lectures / Lessons',
                      hintText: 'e.g. 40',
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style:
                      GoogleFonts.poppins(color: AppColors.textSecondaryLight)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Add Subject'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      final name = nameCtrl.text.trim();
      final count = int.tryParse(countCtrl.text.trim()) ?? 0;
      final style = AppIcons.getStyleFor(name, _activePlan.subjects.length);

      final newSubject = Subject(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        code: codeCtrl.text.trim(),
        total: count,
        trackingType: type,
        colorValue: style.$2.toARGB32(),
        iconCodePoint: style.$1.codePoint,
      );

      // Pre-populate with default revision cycle status
      for (final cycle in _activePlan.revisionCycles) {
        newSubject.revisionStatus[cycle] = false;
      }

      setState(() {
        _activePlan.subjects.add(newSubject);
      });
      await _persistAll();
    }
  }

  // Quick Dialog to edit active plan exam target & backup
  Future<void> _showEditPlanDialog() async {
    final pLabelCtrl =
        TextEditingController(text: _activePlan.primaryTargetLabel);
    final bLabelCtrl =
        TextEditingController(text: _activePlan.backupTargetLabel);
    DateTime? pDate = _activePlan.primaryTargetDate;
    DateTime? bDate = _activePlan.backupTargetDate;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.pastelPink,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.edit_calendar_rounded,
                    color: AppColors.pastelPinkText, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Edit Target Dates',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: pLabelCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Primary Target Label (e.g. May 2027)'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate:
                          pDate ?? DateTime.now().add(const Duration(days: 90)),
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked != null) setD(() => pDate = picked);
                  },
                  icon: const Icon(Icons.calendar_month_rounded, size: 16),
                  label: Text(pDate == null
                      ? 'Set Date'
                      : DateFormat('d MMM yyyy').format(pDate!)),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: bLabelCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Backup Target Label (e.g. September 2027)'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: bDate ??
                          DateTime.now().add(const Duration(days: 180)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked != null) setD(() => bDate = picked);
                  },
                  icon: const Icon(Icons.event_repeat_rounded, size: 16),
                  label: Text(bDate == null
                      ? 'Set Backup Date'
                      : DateFormat('d MMM yyyy').format(bDate!)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style:
                      GoogleFonts.poppins(color: AppColors.textSecondaryLight)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Save Targets'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      setState(() {
        _activePlan.primaryTargetLabel = pLabelCtrl.text.trim();
        _activePlan.primaryTargetDate = pDate;
        _activePlan.backupTargetLabel = bLabelCtrl.text.trim();
        _activePlan.backupTargetDate = bDate;
      });
      await _persistAll();
    }
  }

  Widget _buildPage(int index, bool isWide) {
    if (!_loadedTabs.contains(index)) {
      return const SizedBox.shrink();
    }
    switch (index) {
      case 0:
        return DashboardScreen(
          plan: _activePlan,
          allPlans: _plans,
          isDark: widget.isDark,
          userName: widget.userName,
          onToggleTheme: widget.onToggleTheme,
          onSwitchPlan: _switchPlan,
          onAddSubject: _showAddSubjectDialog,
          onEditPlan: _showEditPlanDialog,
          onStartTimer: () => _selectTab(4),
          onSave: _persistAll,
          onNavigateTab: (idx) => _selectTab(idx),
        );
      case 1:
        return SubjectsScreen(
          plan: _activePlan,
          onSave: _persistAll,
          onAddSubject: _showAddSubjectDialog,
          showAppBar: isWide,
        );
      case 2:
        return ClassesHubScreen(
          studyPlan: _activePlan,
          onPlanUpdated: _persistAll,
        );
      case 3:
        return NotesLibraryScreen(
          studyPlan: _activePlan,
          onPlanUpdated: _persistAll,
        );
      case 4:
        return PomodoroScreen(
          plan: _activePlan,
          onSave: _persistAll,
        );
      case 5:
        return RevisionScreen(
          plan: _activePlan,
          onSave: _persistAll,
          showAppBar: isWide,
        );
      case 6:
        return RemindersScreen(
          plan: _activePlan,
          onSave: _persistAll,
          showAppBar: isWide,
        );
      case 7:
        return SettingsScreen(
          activePlan: _activePlan,
          allPlans: _plans,
          isDark: widget.isDark,
          onToggleTheme: widget.onToggleTheme,
          onSwitchPlan: _switchPlan,
          onAddPlan: _addPlan,
          onDeletePlan: _deletePlan,
          onReloadAll: widget.onReloadAll,
          onSave: _persistAll,
          showAppBar: isWide,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 800;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final contentStack = IndexedStack(
      index: _selectedTabIndex,
      children: List.generate(8, (i) => _buildPage(i, isWide)),
    );

    if (isWide) {
      // Elegant Pastel Left Sidebar for Desktop / Tablet Landscape
      return Scaffold(
        body: Row(
          children: [
            Container(
              width: 250,
              decoration: BoxDecoration(
                color: isDark ? AppColors.sidebarDark : AppColors.sidebarLight,
                border: Border(
                  right: BorderSide(
                    color:
                        isDark ? AppColors.borderDark : AppColors.borderLight,
                    width: 1.2,
                  ),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: _buildNavigationContent(
                  context,
                  isDrawer: false,
                  isDark: isDark,
                ),
              ),
            ),

            // Content Area
            Expanded(child: contentStack),
          ],
        ),
      );
    }

    // Narrow layout (Mobile) with Top AppBar & Left Navigation Drawer
    return Scaffold(
      appBar: _buildMobileAppBar(context, isDark),
      drawer: Drawer(
        key: const Key('app_navigation_drawer'),
        backgroundColor:
            isDark ? AppColors.sidebarDark : AppColors.sidebarLight,
        child: SafeArea(
          child: _buildNavigationContent(
            context,
            isDrawer: true,
            isDark: isDark,
          ),
        ),
      ),
      body: contentStack,
    );
  }

  static const List<String> _tabTitles = [
    'Dashboard',
    'Subjects',
    'Classes Hub',
    'Digital Notes',
    'Focus Timer',
    'Revision Pack',
    'Reminders',
    'Settings',
  ];

  PreferredSizeWidget _buildMobileAppBar(BuildContext context, bool isDark) {
    final title =
        (_selectedTabIndex >= 0 && _selectedTabIndex < _tabTitles.length)
            ? _tabTitles[_selectedTabIndex]
            : 'Study Tracker';

    return AppBar(
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      centerTitle: false,
      leading: Builder(
        builder: (ctx) => IconButton(
          key: const Key('hamburger_menu_button'),
          icon: const Icon(Icons.menu_rounded),
          tooltip: 'Open navigation menu',
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color:
              isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
        ),
      ),
      actions: [
        if (_selectedTabIndex == 1)
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Subject',
            onPressed: _showAddSubjectDialog,
          ),
        const Padding(
          padding: EdgeInsets.only(right: 12),
          child: Center(
            child: SyncStatusBadge(showLabel: false),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationContent(
    BuildContext context, {
    required bool isDrawer,
    required bool isDark,
  }) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        // App Brand & Logo (+ optional Drawer Close button)
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.school_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Study Tracker',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: -0.3,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  Text(
                    _activePlan.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            if (isDrawer)
              IconButton(
                key: const Key('drawer_close_button'),
                icon: const Icon(Icons.close_rounded, size: 20),
                tooltip: 'Close menu',
                onPressed: () => Navigator.pop(context),
              ),
          ],
        ),

        // Account Profile & Sync Status Chip
        StreamBuilder<User?>(
          stream: AuthService.authStateChanges,
          initialData: AuthService.currentUser,
          builder: (context, snapshot) {
            final user = snapshot.data;
            if (user != null) {
              final initial = (user.displayName?.isNotEmpty == true
                      ? user.displayName![0]
                      : user.email?[0] ?? 'U')
                  .toUpperCase();
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    if (isDrawer) Navigator.pop(context);
                    _selectTab(7);
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF252248)
                          : AppColors.primaryLight.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF373268)
                            : const Color(0xFFDDD6FE),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 11,
                          backgroundColor: AppColors.primary,
                          child: Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            user.displayName ??
                                user.email?.split('@').first ??
                                'User',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SyncStatusBadge(showLabel: false),
                      ],
                    ),
                  ),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  if (isDrawer) Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AuthScreen(
                        onSuccess: widget.onReloadAll,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF252248)
                        : AppColors.pastelPurple,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF373268)
                          : const Color(0xFFDDD6FE),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_outlined,
                          size: 15, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Sign In to Sync',
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          size: 15, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 12),

        // Navigation Menu Items (all 8 items)
        _buildSidebarItem(
          context: context,
          index: 0,
          icon: Icons.dashboard_rounded,
          label: 'Dashboard',
          isDark: isDark,
          isDrawer: isDrawer,
        ),
        const SizedBox(height: 5),
        _buildSidebarItem(
          context: context,
          index: 1,
          icon: Icons.menu_book_rounded,
          label: 'Subjects',
          isDark: isDark,
          isDrawer: isDrawer,
        ),
        const SizedBox(height: 5),
        _buildSidebarItem(
          context: context,
          index: 2,
          icon: Icons.smart_display_rounded,
          label: 'Classes Hub',
          isDark: isDark,
          isDrawer: isDrawer,
        ),
        const SizedBox(height: 5),
        _buildSidebarItem(
          context: context,
          index: 3,
          icon: Icons.edit_note_rounded,
          label: 'Digital Notes',
          isDark: isDark,
          isDrawer: isDrawer,
        ),
        const SizedBox(height: 5),
        _buildSidebarItem(
          context: context,
          index: 4,
          icon: Icons.timer_rounded,
          label: 'Focus Timer',
          isDark: isDark,
          isDrawer: isDrawer,
        ),
        const SizedBox(height: 5),
        _buildSidebarItem(
          context: context,
          index: 5,
          icon: Icons.sync_rounded,
          label: 'Revision Pack',
          isDark: isDark,
          isDrawer: isDrawer,
        ),
        const SizedBox(height: 5),
        _buildSidebarItem(
          context: context,
          index: 6,
          icon: Icons.notifications_none_rounded,
          label: 'Reminders',
          isDark: isDark,
          isDrawer: isDrawer,
        ),
        const SizedBox(height: 5),
        _buildSidebarItem(
          context: context,
          index: 7,
          icon: Icons.settings_outlined,
          label: 'Settings',
          isDark: isDark,
          isDrawer: isDrawer,
        ),

        const SizedBox(height: 20),

        // Motivational Quote Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF222040) : AppColors.pastelPurple,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? const Color(0xFF333060) : const Color(0xFFE4DCF9),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.eco_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '“Consistency today builds the success you’re proud of tomorrow.”',
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? const Color(0xFFDDD9FA)
                      : const Color(0xFF4C3D82),
                ),
              ),
              const SizedBox(height: 6),
              const Align(
                alignment: Alignment.bottomRight,
                child: Text('💜', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSidebarItem({
    required BuildContext context,
    required int index,
    required IconData icon,
    required String label,
    required bool isDark,
    required bool isDrawer,
  }) {
    final isSelected = _selectedTabIndex == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('nav_item_$index'),
        onTap: () {
          if (isDrawer) {
            Navigator.pop(context);
          }
          if (_selectedTabIndex != index) {
            _selectTab(index);
          }
        },
        borderRadius: BorderRadius.circular(16),
        hoverColor: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : AppColors.primaryLight.withValues(alpha: 0.4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF2C2854) : AppColors.primaryLight)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? AppColors.primary
                    : (isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? (isDark ? Colors.white : AppColors.primary)
                        : (isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/study_plan.dart';
import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/storage_service.dart';
import '../services/youtube_service.dart';
import '../theme/app_theme.dart';
import '../widgets/api_key_dialog.dart';
import '../widgets/sync_status_badge.dart';
import 'auth_screen.dart';

class SettingsScreen extends StatefulWidget {
  final StudyPlan activePlan;
  final List<StudyPlan> allPlans;
  final bool isDark;
  final VoidCallback onToggleTheme;
  final Function(String id) onSwitchPlan;
  final Function(StudyPlan newPlan) onAddPlan;
  final Function(String id) onDeletePlan;
  final VoidCallback onReloadAll;
  final Future<void> Function() onSave;
  final bool? showAppBar;

  const SettingsScreen({
    super.key,
    required this.activePlan,
    required this.allPlans,
    required this.isDark,
    required this.onToggleTheme,
    required this.onSwitchPlan,
    required this.onAddPlan,
    required this.onDeletePlan,
    required this.onReloadAll,
    required this.onSave,
    this.showAppBar,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  StudyPlan get plan => widget.activePlan;
  bool _isLiveApi = false;

  @override
  void initState() {
    super.initState();
    _checkApiStatus();
  }

  Future<void> _checkApiStatus() async {
    final live = await YouTubeService.isLiveApiConfigured();
    if (mounted) setState(() => _isLiveApi = live);
  }

  Future<void> _editPlanDialog() async {
    final nameCtrl = TextEditingController(text: plan.title);
    String category = plan.category;
    final primaryLabelCtrl =
        TextEditingController(text: plan.primaryTargetLabel);
    DateTime? primaryDate = plan.primaryTargetDate;
    final backupLabelCtrl = TextEditingController(text: plan.backupTargetLabel);
    DateTime? backupDate = plan.backupTargetDate;
    double goalHours = plan.dailyGoalMinutes / 60.0;

    final categories = [
      'College / University',
      'Competitive Exam',
      'Professional Exam',
      'Certification',
      'School',
      'Self-Study',
    ];

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Text('Edit Study Plan'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Plan Name'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: categories.contains(category)
                      ? category
                      : categories.first,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setD(() => category = v);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: primaryLabelCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Primary Target Label (e.g. May 2027)'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: primaryDate ??
                          DateTime.now().add(const Duration(days: 90)),
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked != null) setD(() => primaryDate = picked);
                  },
                  icon: const Icon(Icons.calendar_today_rounded, size: 16),
                  label: Text(
                    primaryDate == null
                        ? 'Set Date'
                        : DateFormat('d MMM yyyy').format(primaryDate!),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: backupLabelCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Backup Target Label (Optional)'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: backupDate ??
                          DateTime.now().add(const Duration(days: 180)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked != null) setD(() => backupDate = picked);
                  },
                  icon: const Icon(Icons.event_repeat_rounded, size: 16),
                  label: Text(
                    backupDate == null
                        ? 'Set Backup Date'
                        : DateFormat('d MMM yyyy').format(backupDate!),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Daily Goal: ${goalHours.toStringAsFixed(1)} hrs/day',
                  style: GoogleFonts.poppins(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
                Slider(
                  value: goalHours,
                  min: 0.5,
                  max: 12.0,
                  divisions: 23,
                  label: '${goalHours.toStringAsFixed(1)} hrs',
                  onChanged: (v) => setD(() => goalHours = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );

    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      plan.title = nameCtrl.text.trim();
      plan.category = category;
      plan.primaryTargetLabel = primaryLabelCtrl.text.trim();
      plan.primaryTargetDate = primaryDate;
      plan.backupTargetLabel = backupLabelCtrl.text.trim();
      plan.backupTargetDate = backupDate;
      plan.dailyGoalMinutes = (goalHours * 60).round();
      await widget.onSave();
      if (mounted) setState(() {});
    }
  }

  Future<void> _createNewPlanDialog() async {
    final titleCtrl = TextEditingController(text: 'New Study Plan');
    String category = 'Professional Exam';

    final categories = [
      'College / University',
      'Competitive Exam',
      'Professional Exam',
      'Certification',
      'School',
      'Self-Study',
    ];

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Text('Create Study Plan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                    labelText: 'Plan Name',
                    hintText: 'e.g. CFA Level 1, Sem 4'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setD(() => category = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Create')),
          ],
        ),
      ),
    );

    if (ok == true && titleCtrl.text.trim().isNotEmpty) {
      final newPlan = StudyPlan(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: titleCtrl.text.trim(),
        category: category,
      );
      widget.onAddPlan(newPlan);
      if (mounted) setState(() {});
    }
  }

  Future<void> _manageCyclesDialog() async {
    final cycles = List<String>.from(plan.revisionCycles);
    final newCycleCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Text('Manage Revision Cycles'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...cycles.map((c) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.sync_rounded,
                            size: 18, color: AppColors.primary),
                        title: Text(c,
                            style: GoogleFonts.poppins(
                                fontSize: 13, fontWeight: FontWeight.w500)),
                        trailing: IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16),
                          onPressed: () {
                            setD(() => cycles.remove(c));
                          },
                        ),
                      )),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: newCycleCtrl,
                          decoration: const InputDecoration(
                            hintText: 'New cycle name...',
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.add_rounded),
                        onPressed: () {
                          if (newCycleCtrl.text.trim().isNotEmpty) {
                            setD(() {
                              cycles.add(newCycleCtrl.text.trim());
                              newCycleCtrl.clear();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                plan.revisionCycles = cycles;
                for (final s in plan.subjects) {
                  for (final c in cycles) {
                    s.revisionStatus.putIfAbsent(c, () => false);
                  }
                }
                await widget.onSave();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save Cycles'),
            ),
          ],
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  // Backup Export: Copy JSON string to clipboard
  Future<void> _exportBackup() async {
    final jsonStr = StorageService.exportBackupJson(widget.allPlans);
    await Clipboard.setData(ClipboardData(text: jsonStr));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('✓ Full study data copied to clipboard! Save it safely.'),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  // Backup Import: Paste JSON string & restore
  Future<void> _importBackupDialog() async {
    final ctrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Import Backup JSON'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paste your exported JSON backup text below. This will safely restore your study plans and progress.',
              style: GoogleFonts.poppins(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: 'Paste JSON here...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restore Data')),
        ],
      ),
    );

    if (ok == true && ctrl.text.trim().isNotEmpty) {
      try {
        final raw = ctrl.text.trim();
        final plans = StorageService.importBackupJson(raw);
        if (plans.isNotEmpty) {
          await StorageService.savePlans(plans);
          await StorageService.saveActivePlanId(plans.first.id);
          widget.onReloadAll();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✓ Data restored successfully!')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Error restoring data: Invalid JSON. Details: $e')),
          );
        }
      }
    }
  }

  Future<void> _resetAllDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Reset All Data?'),
        content: Text(
          'This will permanently delete all subjects, notes, timer history, and study plans. Are you absolutely sure?',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset Everything'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await StorageService.clearAllData();
      widget.onReloadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data has been reset.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final isWide = MediaQuery.of(context).size.width >= 800;
    final shouldShowAppBar = widget.showAppBar ?? isWide;

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      appBar: shouldShowAppBar
          ? AppBar(
              title: Text(
                'Settings & Plans',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 18),
              ),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          // 0. ACCOUNT & CLOUD SYNCHRONIZATION
          StreamBuilder<User?>(
            stream: AuthService.authStateChanges,
            initialData: AuthService.currentUser,
            builder: (context, snapshot) {
              final user = snapshot.data;
              return _buildAccountCard(isDark, user);
            },
          ),
          const SizedBox(height: 14),

          // 1. ACTIVE STUDY PLAN MANAGEMENT
          _buildSettingsCard(
            isDark: isDark,
            icon: Icons.school_rounded,
            iconBg: AppColors.pastelPurple,
            iconFg: AppColors.primary,
            title: 'Study Plan',
            subtitle: 'Manage your active plan, targets, and goals',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.title,
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            plan.category,
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
                    IconButton.outlined(
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      tooltip: 'Edit Plan Targets & Goal',
                      onPressed: _editPlanDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Switcher dropdown
                if (widget.allPlans.length > 1) ...[
                  DropdownButtonFormField<String>(
                    initialValue: plan.id,
                    decoration: const InputDecoration(labelText: 'Active Plan'),
                    items: widget.allPlans.map((p) {
                      return DropdownMenuItem(
                          value: p.id, child: Text(p.title));
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) widget.onSwitchPlan(v);
                    },
                  ),
                  const SizedBox(height: 14),
                ],

                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _createNewPlanDialog,
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('New Plan'),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                    if (widget.allPlans.length > 1) ...[
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        icon:
                            const Icon(Icons.delete_outline_rounded, size: 16),
                        label: const Text('Delete Plan'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: const BorderSide(color: AppColors.danger),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                        ),
                        onPressed: () => widget.onDeletePlan(plan.id),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. REVISION CYCLES CUSTOMIZATION
          _buildSettingsCard(
            isDark: isDark,
            icon: Icons.sync_rounded,
            iconBg: AppColors.pastelBlue,
            iconFg: AppColors.pastelBlueText,
            title: 'Revision Cycles',
            subtitle: 'Currently: ${plan.revisionCycles.join(', ')}',
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _manageCyclesDialog,
          ),
          const SizedBox(height: 14),

          // 3. APPEARANCE (Dark / Light Theme)
          _buildSettingsCard(
            isDark: isDark,
            icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            iconBg: AppColors.pastelOrange,
            iconFg: AppColors.pastelOrangeText,
            title: 'Dark Mode',
            subtitle: isDark ? 'Dark theme active' : 'Light theme active',
            trailing: Switch(
              value: widget.isDark,
              activeThumbColor: AppColors.primary,
              activeTrackColor: AppColors.primaryLight,
              onChanged: (_) => widget.onToggleTheme(),
            ),
          ),
          const SizedBox(height: 14),

          // 4. CLASSES HUB & YOUTUBE API
          _buildSettingsCard(
            isDark: isDark,
            icon: Icons.smart_display_rounded,
            iconBg: _isLiveApi ? AppColors.pastelPurple : AppColors.pastelMint,
            iconFg: _isLiveApi ? AppColors.primary : AppColors.pastelMintText,
            title: 'Classes Hub & YouTube API',
            subtitle: _isLiveApi
                ? 'Live YouTube Data API v3 configured'
                : 'Demo Mode active (Curated educational catalog)',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color:
                    _isLiveApi ? AppColors.primaryLight : AppColors.pastelMint,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _isLiveApi ? 'Configure' : 'Setup API',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color:
                      _isLiveApi ? AppColors.primary : AppColors.pastelMintText,
                ),
              ),
            ),
            onTap: () async {
              final changed = await ApiKeyDialog.show(context);
              if (changed == true) {
                _checkApiStatus();
              }
            },
          ),
          const SizedBox(height: 14),

          // 5. DATA BACKUP & RESTORE
          _buildSettingsCard(
            isDark: isDark,
            icon: Icons.cloud_sync_rounded,
            iconBg: AppColors.pastelMint,
            iconFg: AppColors.pastelMintText,
            title: 'Backup & Restore',
            subtitle: 'Export or import your complete study progress via JSON',
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Export JSON'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryLight,
                      foregroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _exportBackup,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.paste_rounded, size: 16),
                    label: const Text('Import JSON'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _importBackupDialog,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 5. RESET APPLICATION DATA
          _buildSettingsCard(
            isDark: isDark,
            icon: Icons.delete_forever_rounded,
            iconBg: AppColors.pastelPink,
            iconFg: AppColors.pastelPinkText,
            title: 'Reset Study Data',
            subtitle: 'Clear all subjects, plans, and session history',
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppColors.danger),
            onTap: _resetAllDialog,
          ),
        ],
      ),
    );
  }

  Future<void> _handleSyncNow(String uid) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await CloudSyncService.sync(uid);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor:
            result.isSuccess ? AppColors.success : AppColors.warning,
      ),
    );
    if (result.isSuccess) {
      widget.onReloadAll();
    }
  }

  Future<void> _handleRestoreCloud(String uid) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Restore Cloud Backup?'),
        content: Text(
          'This will restore your study plans, notebooks, and settings from your cloud account. Any unsaved local changes may be overwritten.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.cloud_download_rounded, size: 16),
            label: const Text('Restore'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final result = await CloudSyncService.restoreCloudToLocal(uid);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor:
              result.isSuccess ? AppColors.success : AppColors.warning,
        ),
      );
      if (result.isSuccess) {
        widget.onReloadAll();
      }
    }
  }

  Future<void> _handleSignOut() async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Sign Out?'),
        content: Text(
          'Your study data will stay saved locally on this device. You can sign back in anytime to resume cloud backup.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.signOut();
      await CloudSyncService.resetSyncState();
      if (mounted) {
        setState(() {});
        messenger.showSnackBar(
          const SnackBar(content: Text('Signed out successfully.')),
        );
      }
    }
  }

  Future<void> _handleDeleteAccount() async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Delete Cloud Account?'),
        content: Text(
          'Are you sure you want to permanently delete your cloud account? This removes your cloud authentication profile. Your local data on this device will remain until manually reset.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await AuthService.deleteAccount();
      if (!mounted) return;
      if (res.isSuccess) {
        await CloudSyncService.resetSyncState();
        setState(() {});
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Your account has been deleted.'),
            backgroundColor: AppColors.danger,
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(res.errorMessage ?? 'Failed to delete account.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Widget _buildAccountCard(bool isDark, User? user) {
    if (user == null) {
      return _buildSettingsCard(
        isDark: isDark,
        icon: Icons.cloud_queue_rounded,
        iconBg: AppColors.pastelPurple,
        iconFg: AppColors.primary,
        title: 'Cloud Backup & Sync',
        subtitle:
            'Sign in to sync your study plans, notes, and progress across devices',
        trailing: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AuthScreen(
                  onSuccess: () {
                    widget.onReloadAll();
                    if (mounted) setState(() {});
                  },
                ),
              ),
            );
          },
          child: const Text('Sign In'),
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : AppColors.primaryLight.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AuthService.isPlaceholderConfigured
                      ? 'Local storage active. To connect your Study Tracker Firebase project, replace the placeholder Web API keys in lib/firebase_options.dart.'
                      : 'Local storage active. Sign in or register to enable cloud backup, synchronization, and device recovery.',
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final initial = (user.displayName?.isNotEmpty == true
            ? user.displayName![0]
            : user.email?.isNotEmpty == true
                ? user.email![0]
                : 'U')
        .toUpperCase();

    return _buildSettingsCard(
      isDark: isDark,
      icon: Icons.cloud_done_rounded,
      iconBg: AppColors.pastelMint,
      iconFg: AppColors.pastelMintText,
      title: 'Cloud Account',
      subtitle: user.email ?? 'Connected',
      trailing: const SyncStatusBadge(showLabel: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary,
                child: Text(
                  initial,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName ?? 'Study Tracker User',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                      ),
                    ),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.email ?? '',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (user.emailVerified)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.pastelMint,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Verified',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.pastelMintText,
                              ),
                            ),
                          )
                        else
                          InkWell(
                            onTap: () async {
                              final res =
                                  await AuthService.sendEmailVerification();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res.isSuccess
                                      ? 'Verification email sent to ${user.email}!'
                                      : res.errorMessage ??
                                          'Failed to send email.'),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.pastelOrange,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Verify',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.pastelOrangeText,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ValueListenableBuilder<DateTime?>(
            valueListenable: CloudSyncService.lastSyncNotifier,
            builder: (ctx, lastSync, _) {
              final text = lastSync != null
                  ? 'Last backed up: ${DateFormat('d MMM yyyy, h:mm a').format(lastSync)}'
                  : 'Cloud status: Ready to sync';
              return Text(
                text,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.sync_rounded, size: 16),
                  label: const Text('Sync Now'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    foregroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  onPressed: () => _handleSyncNow(user.uid),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.cloud_download_rounded, size: 16),
                  label: const Text('Restore Cloud'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  onPressed: () => _handleRestoreCloud(user.uid),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.logout_rounded, size: 15),
                label: const Text('Sign Out'),
                onPressed: _handleSignOut,
              ),
              TextButton.icon(
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 15, color: AppColors.danger),
                label: const Text('Delete Account',
                    style: TextStyle(color: AppColors.danger)),
                onPressed: _handleDeleteAccount,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard({
    required bool isDark,
    required IconData icon,
    required Color iconBg,
    required Color iconFg,
    required String title,
    required String subtitle,
    Widget? child,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final content = Container(
      padding: const EdgeInsets.all(18),
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark ? iconBg.withValues(alpha: 0.22) : iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconFg, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    Text(
                      subtitle,
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
              if (trailing != null) trailing,
            ],
          ),
          if (child != null) ...[
            const SizedBox(height: 14),
            child,
          ],
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: content,
        ),
      );
    }

    return content;
  }
}

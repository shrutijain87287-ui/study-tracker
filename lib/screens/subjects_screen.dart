import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/study_plan.dart';
import '../theme/app_theme.dart';
import 'subject_detail_screen.dart';

class SubjectsScreen extends StatefulWidget {
  final StudyPlan plan;
  final Future<void> Function() onSave;
  final VoidCallback onAddSubject;
  final bool? showAppBar;

  const SubjectsScreen({
    super.key,
    required this.plan,
    required this.onSave,
    required this.onAddSubject,
    this.showAppBar,
  });

  @override
  State<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends State<SubjectsScreen> {
  String _search = '';

  StudyPlan get plan => widget.plan;

  List<Subject> get filteredSubjects {
    if (_search.trim().isEmpty) return plan.subjects;
    final q = _search.toLowerCase();
    return plan.subjects
        .where((s) =>
            s.name.toLowerCase().contains(q) ||
            s.code.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width >= 800;
    final shouldShowAppBar = widget.showAppBar ?? isWide;

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      appBar: shouldShowAppBar
          ? AppBar(
              title: Text(
                'Subjects & Courses',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 18),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.add_rounded),
                  tooltip: 'Add Subject',
                  onPressed: widget.onAddSubject,
                ),
              ],
            )
          : null,
      body: Column(
        children: [
          // Search & Filter Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search subjects, paper codes...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () => setState(() => _search = ''),
                      )
                    : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (val) => setState(() => _search = val),
            ),
          ),

          // Subjects List / Grid
          Expanded(
            child: filteredSubjects.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: AppColors.primaryLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.menu_book_rounded,
                                size: 36, color: AppColors.primary),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            plan.subjects.isEmpty
                                ? 'No subjects created yet'
                                : 'No matching subjects found',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          if (plan.subjects.isEmpty)
                            FilledButton.icon(
                              onPressed: widget.onAddSubject,
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Add Subject'),
                            ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                    itemCount: filteredSubjects.length,
                    itemBuilder: (context, i) {
                      final s = filteredSubjects[i];
                      final style = AppIcons.getStyleFor(s.name, i);
                      final icon = AppIcons.getIconFromCode(s.iconCodePoint);
                      final containerColor = s.colorValue != null
                          ? Color(s.colorValue!).withValues(alpha: 0.15)
                          : style.$2;
                      final iconColor = s.colorValue != null
                          ? Color(s.colorValue!)
                          : style.$3;

                      final done = s.effectiveCompleted;
                      final total = s.effectiveTotal;
                      final pct = s.progressPercent;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color:
                              isDark ? AppColors.cardDark : AppColors.cardLight,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: isDark
                                ? AppColors.borderDark
                                : AppColors.borderLight,
                            width: 1.2,
                          ),
                          boxShadow: AppColors.softShadow,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SubjectDetailScreen(
                                    subject: s,
                                    plan: plan,
                                    onSave: widget.onSave,
                                  ),
                                ),
                              );
                              await widget.onSave();
                              if (mounted) setState(() {});
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? containerColor.withValues(
                                                  alpha: 0.25)
                                              : containerColor,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        child: Icon(icon,
                                            color: iconColor, size: 22),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              s.name,
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: isDark
                                                    ? AppColors.textPrimaryDark
                                                    : AppColors
                                                        .textPrimaryLight,
                                              ),
                                            ),
                                            Text(
                                              s.trackingType ==
                                                      TrackingType.chapters
                                                  ? '${s.chapters.length} chapters • $done/$total topics'
                                                  : s.trackingType ==
                                                          TrackingType.tasks
                                                      ? '${s.tasks.length} tasks • $done/$total done'
                                                      : '$done of $total lectures completed',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: isDark
                                                    ? AppColors
                                                        .textSecondaryDark
                                                    : AppColors
                                                        .textSecondaryLight,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        icon:
                                            const Icon(Icons.more_vert_rounded),
                                        onSelected: (action) async {
                                          if (action == 'edit') {
                                            _editSubjectDialog(s);
                                          } else if (action == 'delete') {
                                            _deleteSubjectDialog(s);
                                          }
                                        },
                                        itemBuilder: (ctx) => [
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                Icon(Icons.edit_rounded,
                                                    size: 18),
                                                SizedBox(width: 8),
                                                Text('Edit Details'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(
                                                    Icons
                                                        .delete_outline_rounded,
                                                    size: 18,
                                                    color: Colors.redAccent),
                                                SizedBox(width: 8),
                                                Text('Delete',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.redAccent)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),

                                  // Progress bar
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: s.progressRatio,
                                      minHeight: 6,
                                      backgroundColor: isDark
                                          ? const Color(0xFF282645)
                                          : const Color(0xFFEDE9F8),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          iconColor),
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '$pct% completed • ${s.pendingCount} pending',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w500,
                                            color: isDark
                                                ? AppColors.textSecondaryDark
                                                : AppColors.textSecondaryLight,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Row(
                                        children: [
                                          if (s.notes.isNotEmpty) ...[
                                            const Icon(
                                                Icons.lightbulb_outline_rounded,
                                                size: 14,
                                                color: AppColors.primary),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${s.notes.length}',
                                              style: GoogleFonts.poppins(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                          ],
                                          Text(
                                            'Manage',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: iconColor,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(Icons.arrow_forward_rounded,
                                              size: 14, color: iconColor),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _editSubjectDialog(Subject s) async {
    final nameCtrl = TextEditingController(text: s.name);
    final codeCtrl = TextEditingController(text: s.code);
    final countCtrl = TextEditingController(text: s.total.toString());

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Edit Subject'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Subject Name'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeCtrl,
              decoration:
                  const InputDecoration(labelText: 'Code / Tag (Optional)'),
            ),
            if (s.trackingType == TrackingType.flatLectures) ...[
              const SizedBox(height: 12),
              TextField(
                controller: countCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Total Lectures'),
              ),
            ],
          ],
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
    );

    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      s.name = nameCtrl.text.trim();
      s.code = codeCtrl.text.trim();
      if (s.trackingType == TrackingType.flatLectures) {
        final count = int.tryParse(countCtrl.text.trim());
        if (count != null && count >= 0) {
          s.total = count;
          s.completed.removeWhere((idx) => idx > count);
        }
      }
      await widget.onSave();
      if (mounted) setState(() {});
    }
  }

  Future<void> _deleteSubjectDialog(Subject s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Delete Subject?'),
        content: Text(
            'Are you sure you want to delete "${s.name}" and all its records? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok == true) {
      plan.subjects.remove(s);
      await widget.onSave();
      if (mounted) setState(() {});
    }
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/study_plan.dart';
import '../theme/app_theme.dart';

class SubjectDetailScreen extends StatefulWidget {
  final Subject subject;
  final StudyPlan plan;
  final Future<void> Function() onSave;

  const SubjectDetailScreen({
    super.key,
    required this.subject,
    required this.plan,
    required this.onSave,
  });

  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _noteTextCtrl = TextEditingController();
  String _selectedNoteTag = 'General';
  String _notesSearchQuery = '';

  Subject get s => widget.subject;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _noteTextCtrl.dispose();
    super.dispose();
  }

  Future<void> _persist() async {
    await widget.onSave();
    if (mounted) setState(() {});
  }

  Color get _subjectColor =>
      s.colorValue != null ? Color(s.colorValue!) : AppColors.primary;

  IconData get _subjectIcon => AppIcons.getIconFromCode(s.iconCodePoint);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = s.effectiveTotal;
    final completed = s.effectiveCompleted;
    final progress = s.progressRatio;
    final pct = s.progressPercent;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _subjectColor.withAlpha(40),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_subjectIcon, color: _subjectColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  if (s.code.isNotEmpty)
                    Text(
                      s.code,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
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
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Tracking Mode Settings',
            onPressed: _showTrackingModeDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight,
          labelStyle:
              GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.checklist_rounded), text: 'Curriculum'),
            Tab(icon: Icon(Icons.sync_rounded), text: 'Revision Cycles'),
            Tab(
                icon: Icon(Icons.lightbulb_outline_rounded),
                text: 'Notes & Formulas'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Header banner with progress
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                width: 1.2,
              ),
              boxShadow: AppColors.softShadow,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$completed of $total items completed',
                        style: GoogleFonts.poppins(
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: isDark
                              ? const Color(0xFF282645)
                              : const Color(0xFFEDE9F8),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(_subjectColor),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Text(
                  '$pct%',
                  style: GoogleFonts.poppins(
                    color: _subjectColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
          ),

          // Tabs content
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildCurriculumTab(isDark),
                _buildRevisionTab(isDark),
                _buildNotesTab(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // TAB 1: CURRICULUM (Flat Lectures, Chapters, or Tasks)
  // ─────────────────────────────────────────────────────────
  Widget _buildCurriculumTab(bool isDark) {
    switch (s.trackingType) {
      case TrackingType.flatLectures:
        return _buildFlatLecturesView(isDark);
      case TrackingType.chapters:
        return _buildChaptersView(isDark);
      case TrackingType.tasks:
        return _buildTasksView(isDark);
    }
  }

  // 1A. Flat Lectures Mode
  Widget _buildFlatLecturesView(bool isDark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Tick each lecture as you complete it. Untick if you need to revisit.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _editTotalLectures,
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Edit Count'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (s.total == 0)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const Icon(Icons.video_library_outlined,
                      size: 48, color: AppColors.primary),
                  const SizedBox(height: 12),
                  Text('No lectures configured yet.',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: _editTotalLectures,
                    child: const Text('Set Total Lectures'),
                  ),
                ],
              ),
            ),
          )
        else
          Card(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: s.total,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
              itemBuilder: (context, i) {
                final lectureNum = i + 1;
                final done = s.completed.contains(lectureNum);

                return CheckboxListTile(
                  value: done,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  activeColor: AppColors.success,
                  checkColor: Colors.white,
                  title: Text(
                    'Lecture $lectureNum',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      decoration: done ? TextDecoration.lineThrough : null,
                      color: done
                          ? (isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight)
                          : (isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight),
                    ),
                  ),
                  subtitle: Text(
                    done ? 'Completed ✓' : 'Pending',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: done
                          ? AppColors.success
                          : (isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight),
                    ),
                  ),
                  onChanged: (val) async {
                    if (val == true) {
                      if (!s.completed.contains(lectureNum)) {
                        s.completed.add(lectureNum);
                      }
                    } else {
                      s.completed.remove(lectureNum);
                    }
                    s.completed.sort();
                    await _persist();
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  // 1B. Chapters & Topics Mode
  Widget _buildChaptersView(bool isDark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Chapters & Topics (${s.chapters.length})',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: _addChapterDialog,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Chapter'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (s.chapters.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const Icon(Icons.menu_book_rounded,
                      size: 48, color: AppColors.primary),
                  const SizedBox(height: 12),
                  Text('No chapters added yet.',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(
                      'Organize your curriculum into chapters with specific topics and lessons.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight)),
                  const SizedBox(height: 14),
                  FilledButton.tonal(
                    onPressed: _addChapterDialog,
                    child: const Text('Create First Chapter'),
                  ),
                ],
              ),
            ),
          )
        else
          ...s.chapters.asMap().entries.map((cEntry) {
            final cIndex = cEntry.key;
            final chapter = cEntry.value;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                initiallyExpanded: true,
                shape: const Border(),
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: chapter.isCompleted
                      ? AppColors.successLight
                      : AppColors.primaryLight.withAlpha(60),
                  child: Icon(
                    chapter.isCompleted
                        ? Icons.check_rounded
                        : Icons.folder_outlined,
                    color: chapter.isCompleted
                        ? AppColors.success
                        : AppColors.primary,
                    size: 16,
                  ),
                ),
                title: Text(
                  chapter.title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                subtitle: Text(
                  '${chapter.completedCount} of ${chapter.totalCount} completed',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add_task_rounded, size: 20),
                      tooltip: 'Add Topic/Lesson',
                      onPressed: () => _addTopicDialog(chapter),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 18, color: Colors.redAccent),
                      tooltip: 'Delete Chapter',
                      onPressed: () async {
                        setState(() => s.chapters.removeAt(cIndex));
                        await _persist();
                      },
                    ),
                  ],
                ),
                children: [
                  Divider(
                      height: 1,
                      color: isDark
                          ? AppColors.borderDark
                          : AppColors.borderLight),
                  if (chapter.topics.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No topics yet. Tap the + icon to add lessons or topics.',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    )
                  else
                    ...chapter.topics.asMap().entries.map((tEntry) {
                      final tIndex = tEntry.key;
                      final topic = tEntry.value;

                      return CheckboxListTile(
                        value: topic.isCompleted,
                        dense: true,
                        activeColor: AppColors.success,
                        title: Text(
                          topic.title,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            decoration: topic.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color: topic.isCompleted
                                ? (isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight)
                                : (isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight),
                          ),
                        ),
                        secondary: IconButton(
                          icon: const Icon(Icons.remove_circle_outline_rounded,
                              size: 16, color: Colors.redAccent),
                          onPressed: () async {
                            setState(() => chapter.topics.removeAt(tIndex));
                            await _persist();
                          },
                        ),
                        onChanged: (val) async {
                          setState(() => topic.isCompleted = val ?? false);
                          await _persist();
                        },
                      );
                    }),
                ],
              ),
            );
          }),
      ],
    );
  }

  // 1C. Tasks Checklist Mode
  Widget _buildTasksView(bool isDark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tasks & Practice Sets (${s.tasks.length})',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: _addTaskDialog,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Task'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (s.tasks.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const Icon(Icons.checklist_rounded,
                      size: 48, color: AppColors.primary),
                  const SizedBox(height: 12),
                  Text('No tasks added yet.',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 14),
                  FilledButton.tonal(
                    onPressed: _addTaskDialog,
                    child: const Text('Add First Task'),
                  ),
                ],
              ),
            ),
          )
        else
          Card(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: s.tasks.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
              itemBuilder: (context, i) {
                final task = s.tasks[i];
                return CheckboxListTile(
                  value: task.isCompleted,
                  activeColor: AppColors.success,
                  title: Text(
                    task.title,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      decoration:
                          task.isCompleted ? TextDecoration.lineThrough : null,
                      color: task.isCompleted
                          ? (isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight)
                          : (isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight),
                    ),
                  ),
                  subtitle: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withAlpha(50),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          task.type,
                          style: GoogleFonts.poppins(
                              fontSize: 10, color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '~${task.estimatedMinutes} mins',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                  secondary: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: Colors.redAccent, size: 18),
                    onPressed: () async {
                      setState(() => s.tasks.removeAt(i));
                      await _persist();
                    },
                  ),
                  onChanged: (val) async {
                    setState(() => task.isCompleted = val ?? false);
                    await _persist();
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  // TAB 2: REVISION CYCLES
  // ─────────────────────────────────────────────────────────
  Widget _buildRevisionTab(bool isDark) {
    final cycles = widget.plan.revisionCycles;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.sync_rounded, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Revision Rounds for ${s.name}',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Mark revision milestones as you complete each phase (e.g. concepts review, question practice, full mock revision).',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 16),
                ...cycles.map((cycle) {
                  final isDone = s.revisionStatus[cycle] ?? false;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isDone
                          ? AppColors.successLight.withAlpha(60)
                          : (isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDone
                            ? AppColors.success.withAlpha(80)
                            : (isDark
                                ? AppColors.borderDark
                                : AppColors.borderLight),
                      ),
                    ),
                    child: CheckboxListTile(
                      value: isDone,
                      activeColor: AppColors.success,
                      title: Text(
                        cycle,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: isDone
                              ? AppColors.success
                              : (isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight),
                        ),
                      ),
                      subtitle: Text(
                        isDone ? 'Completed' : 'Pending review',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: isDone
                              ? AppColors.success
                              : (isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight),
                        ),
                      ),
                      onChanged: (val) async {
                        setState(() => s.revisionStatus[cycle] = val ?? false);
                        await _persist();
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  // TAB 3: NOTES & IMPORTANT POINTS
  // ─────────────────────────────────────────────────────────
  Widget _buildNotesTab(bool isDark) {
    final filteredNotes = s.notes.where((n) {
      if (_notesSearchQuery.isEmpty) return true;
      return n.text.toLowerCase().contains(_notesSearchQuery.toLowerCase()) ||
          n.tag.toLowerCase().contains(_notesSearchQuery.toLowerCase());
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        // Add note card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Important Point or Formula',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Save definitions, formulas, tricky concepts, or key highlights for your revision pack.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 12),

                // Tag selector
                Wrap(
                  spacing: 6,
                  children: [
                    'General',
                    'Formula',
                    'Definition',
                    'Tricky Question',
                    'Exam Tip'
                  ].map((tag) {
                    final sel = _selectedNoteTag == tag;
                    return ChoiceChip(
                      label: Text(tag),
                      selected: sel,
                      visualDensity: VisualDensity.compact,
                      onSelected: (v) {
                        if (v) setState(() => _selectedNoteTag = tag);
                      },
                      labelStyle: GoogleFonts.poppins(fontSize: 11),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: _noteTextCtrl,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText:
                        'Write your study note, key point, or formula here...',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () async {
                      final text = _noteTextCtrl.text.trim();
                      if (text.isEmpty) return;
                      s.notes.add(
                        StudyNote(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          text: text,
                          tag: _selectedNoteTag,
                        ),
                      );
                      _noteTextCtrl.clear();
                      await _persist();
                    },
                    icon: const Icon(Icons.bookmark_add_rounded, size: 18),
                    label: const Text('Save Note'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Search & Notes list header
        Row(
          children: [
            Text(
              'Saved Points (${s.notes.length})',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: 180,
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search notes...',
                  prefixIcon: Icon(Icons.search_rounded, size: 18),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                onChanged: (val) => setState(() => _notesSearchQuery = val),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (filteredNotes.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                'No notes found.',
                style: GoogleFonts.poppins(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ),
          )
        else
          ...filteredNotes.asMap().entries.map((entry) {
            final note = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(
                  note.text,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                subtitle: Row(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withAlpha(40),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        note.tag,
                        style: GoogleFonts.poppins(
                            fontSize: 10, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        DateFormat.yMMMd().format(note.createdAt),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: Colors.redAccent, size: 18),
                  onPressed: () async {
                    setState(() => s.notes.remove(note));
                    await _persist();
                  },
                ),
              ),
            );
          }),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  // DIALOG HELPERS
  // ─────────────────────────────────────────────────────────
  Future<void> _showTrackingModeDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Tracking Mode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                s.trackingType == TrackingType.flatLectures
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: AppColors.primary,
              ),
              title: const Text('Lecture Counter (1..N)'),
              subtitle: const Text('Simple list of numbered lectures'),
              onTap: () async {
                setState(() => s.trackingType = TrackingType.flatLectures);
                Navigator.pop(ctx);
                await _persist();
              },
            ),
            ListTile(
              leading: Icon(
                s.trackingType == TrackingType.chapters
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: AppColors.primary,
              ),
              title: const Text('Chapters & Topics'),
              subtitle:
                  const Text('Hierarchical structure with chapters and topics'),
              onTap: () async {
                setState(() => s.trackingType = TrackingType.chapters);
                Navigator.pop(ctx);
                await _persist();
              },
            ),
            ListTile(
              leading: Icon(
                s.trackingType == TrackingType.tasks
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: AppColors.primary,
              ),
              title: const Text('Tasks / Practice Sets'),
              subtitle: const Text('Direct checklist of tasks and questions'),
              onTap: () async {
                setState(() => s.trackingType = TrackingType.tasks);
                Navigator.pop(ctx);
                await _persist();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editTotalLectures() async {
    final ctrl = TextEditingController(text: s.total.toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Total Lectures'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              labelText: 'Total count', hintText: 'e.g. 45'),
          autofocus: true,
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
    final count = int.tryParse(ctrl.text.trim());
    if (ok == true && count != null && count >= 0) {
      setState(() {
        s.total = count;
        s.completed.removeWhere((idx) => idx > count);
      });
      await _persist();
    }
  }

  Future<void> _addChapterDialog() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Chapter'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
              labelText: 'Chapter Title',
              hintText: 'e.g. Chapter 1: Introduction'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      setState(() {
        s.chapters.add(
          Chapter(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: ctrl.text.trim(),
          ),
        );
      });
      await _persist();
    }
  }

  Future<void> _addTopicDialog(Chapter chapter) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Lesson to ${chapter.title}'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
              labelText: 'Topic Title',
              hintText: 'e.g. Topic 1.1: Core Concepts'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      setState(() {
        chapter.topics.add(
          StudyTask(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: ctrl.text.trim(),
          ),
        );
      });
      await _persist();
    }
  }

  Future<void> _addTaskDialog() async {
    final ctrl = TextEditingController();
    String type = 'Practice';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Add Task / Practice Set'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(
                    labelText: 'Task Title',
                    hintText: 'e.g. Mock Test 1, End of chapter Qs'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(
                      value: 'Lecture', child: Text('Lecture / Video')),
                  DropdownMenuItem(
                      value: 'Reading', child: Text('Textbook Reading')),
                  DropdownMenuItem(
                      value: 'Practice', child: Text('Practice Questions')),
                  DropdownMenuItem(
                      value: 'Revision', child: Text('Revision Session')),
                ],
                onChanged: (v) {
                  if (v != null) setD(() => type = v);
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
                child: const Text('Add')),
          ],
        ),
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      setState(() {
        s.tasks.add(
          StudyTask(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: ctrl.text.trim(),
            type: type,
          ),
        );
      });
      await _persist();
    }
  }
}

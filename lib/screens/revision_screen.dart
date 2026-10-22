import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/study_plan.dart';
import '../theme/app_theme.dart';

class RevisionScreen extends StatefulWidget {
  final StudyPlan plan;
  final Future<void> Function() onSave;
  final bool? showAppBar;

  const RevisionScreen({
    super.key,
    required this.plan,
    required this.onSave,
    this.showAppBar,
  });

  @override
  State<RevisionScreen> createState() => _RevisionScreenState();
}

class _RevisionScreenState extends State<RevisionScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  String _tagFilter = 'All';
  String? _subjectFilter;
  String _searchQuery = '';

  StudyPlan get plan => widget.plan;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _persist() async {
    await widget.onSave();
    if (mounted) setState(() {});
  }

  // Collect all notes across all subjects
  List<(Subject, StudyNote)> get allNotes {
    final list = <(Subject, StudyNote)>[];
    for (final s in plan.subjects) {
      for (final n in s.notes) {
        list.add((s, n));
      }
    }
    // Sort chronological: newest to oldest
    list.sort((a, b) => b.$2.createdAt.compareTo(a.$2.createdAt));
    return list;
  }

  List<(Subject, StudyNote)> get filteredNotes {
    return allNotes.where((item) {
      final s = item.$1;
      final n = item.$2;
      if (_subjectFilter != null && s.id != _subjectFilter) return false;
      if (_tagFilter != 'All' && n.tag != _tagFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!n.text.toLowerCase().contains(q) &&
            !s.name.toLowerCase().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  // Dialog to Add a new Revision Cycle
  Future<void> _showAddCycleDialog() async {
    final ctrl = TextEditingController(
        text: 'R${plan.revisionCycles.length + 1} (Final Pass)');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Add Revision Cycle'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Cycle Name',
            hintText: 'e.g. R4 (Rapid Recall), Mock Test Review',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add Cycle')),
        ],
      ),
    );

    if (ok == true && ctrl.text.trim().isNotEmpty) {
      final name = ctrl.text.trim();
      if (!plan.revisionCycles.contains(name)) {
        setState(() {
          plan.revisionCycles.add(name);
          for (final s in plan.subjects) {
            s.revisionStatus[name] = false;
          }
        });
        await _persist();
      }
    }
  }

  // Quick dialog to add a note to a subject
  Future<void> _showAddNoteDialog() async {
    if (plan.subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Please add at least one subject before adding notes.')),
      );
      return;
    }

    final noteCtrl = TextEditingController();
    String tag = 'Formula';
    String selectedSubId = _subjectFilter ?? plan.subjects.first.id;

    final tags = [
      'Formula',
      'Concept',
      'Mistake',
      'Summary',
      'Exam Tip',
      'General'
    ];

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Text('Save Note / Formula'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedSubId,
                  decoration: const InputDecoration(labelText: 'Subject'),
                  items: plan.subjects
                      .map((s) =>
                          DropdownMenuItem(value: s.id, child: Text(s.name)))
                      .toList(),
                  onChanged: (v) => setD(() => selectedSubId = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: tag,
                  decoration: const InputDecoration(labelText: 'Category Tag'),
                  items: tags
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setD(() => tag = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Important Point / Formula',
                    hintText:
                        'e.g. Current Ratio = Current Assets / Current Liabilities',
                  ),
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
                child: const Text('Save Note')),
          ],
        ),
      ),
    );

    if (ok == true && noteCtrl.text.trim().isNotEmpty) {
      final subject = plan.subjects.firstWhere((s) => s.id == selectedSubId);
      final newNote = StudyNote(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: noteCtrl.text.trim(),
        tag: tag,
      );

      subject.notes.insert(0, newNote);
      await _persist();
    }
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
                'Revision & Notes Pack',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 18),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  tooltip: 'Add Revision Cycle',
                  onPressed: _showAddCycleDialog,
                ),
              ],
              bottom: TabBar(
                controller: _tabCtrl,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                labelStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 13),
                tabs: const [
                  Tab(icon: Icon(Icons.sync_rounded), text: 'Revision Matrix'),
                  Tab(
                      icon: Icon(Icons.collections_bookmark_rounded),
                      text: 'Notes & Formulas'),
                ],
              ),
            )
          : null,
      body: Column(
        children: [
          if (!shouldShowAppBar)
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color:
                        isDark ? AppColors.borderDark : AppColors.borderLight,
                    width: 1,
                  ),
                ),
              ),
              child: TabBar(
                controller: _tabCtrl,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                labelStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 13),
                tabs: const [
                  Tab(icon: Icon(Icons.sync_rounded), text: 'Revision Matrix'),
                  Tab(
                      icon: Icon(Icons.collections_bookmark_rounded),
                      text: 'Notes & Formulas'),
                ],
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildRevisionMatrixTab(isDark),
                _buildNotesPackTab(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 1. REVISION MATRIX TAB
  // ==========================================
  Widget _buildRevisionMatrixTab(bool isDark) {
    final cycles = plan.revisionCycles;
    final totalRevisionsPossible =
        plan.subjects.length * (cycles.isNotEmpty ? cycles.length : 1);
    final completedRevisions = plan.completedRevisions;
    final progress = totalRevisionsPossible == 0
        ? 0.0
        : (completedRevisions / totalRevisionsPossible).clamp(0.0, 1.0);

    if (plan.subjects.isEmpty) {
      return Center(
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
                child: const Icon(Icons.sync_rounded,
                    size: 36, color: AppColors.primary),
              ),
              const SizedBox(height: 14),
              Text(
                'No subjects to revise yet',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                'Add subjects on the dashboard to track your multi-cycle revisions.',
                style: GoogleFonts.poppins(
                    fontSize: 12.5, color: AppColors.textSecondaryLight),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        // Summary Overview Banner Card
        Container(
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.pastelPurple,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.sync_rounded,
                            color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Multi-Cycle Revision Matrix',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Text(
                            'Track each round of revision before target exam date',
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: _showAddCycleDialog,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add Cycle'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      textStyle: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$completedRevisions of $totalRevisionsPossible revision rounds completed',
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  Text(
                    '${(progress * 100).round()}%',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  backgroundColor: isDark
                      ? const Color(0xFF282645)
                      : const Color(0xFFEDE9F8),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // List of Subject Revision Cards
        ...plan.subjects.map((s) {
          final style = AppIcons.getStyleFor(s.name, plan.subjects.indexOf(s));
          final icon = AppIcons.getIconFromCode(s.iconCodePoint);
          final containerColor = s.colorValue != null
              ? Color(s.colorValue!).withValues(alpha: 0.15)
              : style.$2;
          final iconColor =
              s.colorValue != null ? Color(s.colorValue!) : style.$3;

          final completedCount =
              s.revisionStatus.values.where((v) => v == true).length;
          final isAllDone =
              cycles.isNotEmpty && completedCount == cycles.length;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(18),
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
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDark
                            ? containerColor.withValues(alpha: 0.25)
                            : containerColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: iconColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.name,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                          Text(
                            '${s.effectiveCompleted}/${s.effectiveTotal} curriculum items • $completedCount/${cycles.length} rounds',
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
                    if (isAllDone)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.pastelMint,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'All Done ✓',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.pastelMintText,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // Revision Cycle Chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: cycles.map((cycle) {
                    final done = s.revisionStatus[cycle] ?? false;

                    return FilterChip(
                      selected: done,
                      showCheckmark: true,
                      checkmarkColor: Colors.white,
                      avatar: done
                          ? null
                          : Icon(
                              Icons.circle_outlined,
                              size: 14,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                      selectedColor: AppColors.primary,
                      backgroundColor: isDark
                          ? const Color(0xFF262444)
                          : AppColors.pastelPurple,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      label: Text(
                        cycle,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: done ? FontWeight.w600 : FontWeight.w500,
                          color: done
                              ? Colors.white
                              : (isDark
                                  ? AppColors.textPrimaryDark
                                  : const Color(0xFF4C3D82)),
                        ),
                      ),
                      onSelected: (val) async {
                        s.revisionStatus[cycle] = val;
                        await _persist();
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ==========================================
  // 2. SAVED NOTES PACK TAB
  // ==========================================
  Widget _buildNotesPackTab(bool isDark) {
    final notes = filteredNotes;
    const tagOptions = [
      'All',
      'Formula',
      'Concept',
      'Mistake',
      'Summary',
      'Exam Tip',
      'General'
    ];

    return Column(
      children: [
        // Search & Filter Bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search notes, formulas...',
                        prefixIcon: Icon(Icons.search_rounded, size: 18),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v.trim()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _showAddNoteDialog,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add Note'),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Horizontal tag filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: tagOptions.map((t) {
                    final isSel = _tagFilter == t;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(t),
                        selected: isSel,
                        onSelected: (val) {
                          if (val) setState(() => _tagFilter = t);
                        },
                        selectedColor: AppColors.primaryLight,
                        labelStyle: GoogleFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                          color: isSel
                              ? AppColors.primary
                              : (isDark
                                  ? Colors.white
                                  : AppColors.textPrimaryLight),
                        ),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        // Notes List
        Expanded(
          child: notes.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.note_alt_outlined,
                            size: 40, color: AppColors.textSecondaryLight),
                        const SizedBox(height: 10),
                        Text(
                          'No saved notes found',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          'Use "+ Add Note" or save points from subject detail screens.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.textSecondaryLight),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                  itemCount: notes.length,
                  itemBuilder: (ctx, i) {
                    final item = notes[i];
                    final s = item.$1;
                    final n = item.$2;
                    final dateStr =
                        DateFormat('d MMM yyyy').format(n.createdAt);

                    Color tagBg = AppColors.pastelPurple;
                    Color tagFg = AppColors.primary;
                    if (n.tag == 'Formula') {
                      tagBg = AppColors.pastelBlue;
                      tagFg = AppColors.pastelBlueText;
                    } else if (n.tag == 'Mistake') {
                      tagBg = AppColors.pastelPink;
                      tagFg = AppColors.pastelPinkText;
                    } else if (n.tag == 'Concept') {
                      tagBg = AppColors.pastelMint;
                      tagFg = AppColors.pastelMintText;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color:
                            isDark ? AppColors.cardDark : AppColors.cardLight,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark
                              ? AppColors.borderDark
                              : AppColors.borderLight,
                          width: 1.2,
                        ),
                        boxShadow: AppColors.softShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? tagBg.withValues(alpha: 0.25)
                                          : tagBg,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      n.tag,
                                      style: GoogleFonts.poppins(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : tagFg,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    s.name,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                dateStr,
                                style: GoogleFonts.poppins(
                                  fontSize: 10.5,
                                  color: isDark
                                      ? AppColors.textMutedDark
                                      : AppColors.textMutedLight,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SelectableText(
                            n.text,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              height: 1.45,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded,
                                  size: 16),
                              color: AppColors.danger,
                              tooltip: 'Delete Note',
                              onPressed: () async {
                                s.notes.remove(n);
                                await _persist();
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

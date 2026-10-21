import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/note_model.dart';
import '../models/study_plan.dart';
import '../services/notes_pdf_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'notebook_editor_screen.dart';

class NotesLibraryScreen extends StatefulWidget {
  final StudyPlan? studyPlan;
  final VoidCallback? onPlanUpdated;

  const NotesLibraryScreen({
    super.key,
    this.studyPlan,
    this.onPlanUpdated,
  });

  @override
  State<NotesLibraryScreen> createState() => _NotesLibraryScreenState();
}

class _NotesLibraryScreenState extends State<NotesLibraryScreen> {
  List<Notebook> _notebooks = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _selectedSubjectId = 'All';
  bool _onlyFavorites = false;

  final TextEditingController _searchController = TextEditingController();

  static const List<Color> _presetCoverColors = [
    Color(0xFF6C52EE), // Royal Purple
    Color(0xFF2D9CDB), // Pastel Cyan / Blue
    Color(0xFF10B981), // Emerald Green
    Color(0xFFF59E0B), // Warm Amber
    Color(0xFFE0567A), // Rose Pink
    Color(0xFF8B5CF6), // Soft Violet
    Color(0xFF475569), // Slate
  ];

  @override
  void initState() {
    super.initState();
    _loadNotebooks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNotebooks() async {
    final list = await StorageService.loadNotebooks();
    if (mounted) {
      setState(() {
        _notebooks = list;
        _isLoading = false;
      });
    }
  }

  List<Notebook> get _filteredNotebooks {
    return _notebooks.where((nb) {
      // 1. Category Filter
      if (_selectedCategory != 'All' && nb.category != _selectedCategory) {
        return false;
      }

      // 2. Subject Filter
      if (_selectedSubjectId != 'All' && nb.subjectId != _selectedSubjectId) {
        return false;
      }

      // 3. Favorites Filter
      if (_onlyFavorites && !nb.isFavorite) {
        return false;
      }

      // 4. Search Filter
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final matchTitle = nb.title.toLowerCase().contains(q);
        final matchDesc = (nb.description ?? '').toLowerCase().contains(q);
        final matchSubject = (nb.subjectName ?? '').toLowerCase().contains(q);
        final matchVideo =
            (nb.linkedVideoTitle ?? '').toLowerCase().contains(q);
        final matchTags = nb.tags.any((t) => t.toLowerCase().contains(q));
        final matchPages = nb.pages.any((p) =>
            p.title.toLowerCase().contains(q) ||
            p.content.toLowerCase().contains(q));

        if (!matchTitle &&
            !matchDesc &&
            !matchSubject &&
            !matchVideo &&
            !matchTags &&
            !matchPages) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  List<Notebook> get _recentNotebooks {
    final sorted = List<Notebook>.from(_notebooks)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted.take(4).toList();
  }

  List<String> get _availableCategories {
    final set = <String>{'All'};
    for (final nb in _notebooks) {
      if (nb.category.trim().isNotEmpty) {
        set.add(nb.category.trim());
      }
    }
    if (widget.studyPlan != null &&
        widget.studyPlan!.category.trim().isNotEmpty) {
      set.add(widget.studyPlan!.category.trim());
    }
    return set.toList();
  }

  void _openNotebook(Notebook notebook) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotebookEditorScreen(
          notebook: notebook,
          onNotebookUpdated: () {
            _loadNotebooks();
            widget.onPlanUpdated?.call();
          },
        ),
      ),
    ).then((_) => _loadNotebooks());
  }

  Future<void> _showCreateNotebookDialog({
    String? prefilledTitle,
    String? prefilledVideoId,
    String? prefilledVideoTitle,
    String? prefilledSubjectId,
    String? prefilledSubjectName,
    String? prefilledChapterId,
    String? prefilledChapterTitle,
  }) async {
    final titleController = TextEditingController(
      text: prefilledTitle ?? '',
    );
    final descController = TextEditingController();
    final tagsController = TextEditingController();

    String selectedCategory = widget.studyPlan?.category ?? 'General';
    String? selectedSubId = prefilledSubjectId;
    String? selectedSubName = prefilledSubjectName;
    String? selectedChapId = prefilledChapterId;
    String? selectedChapTitle = prefilledChapterTitle;
    Color selectedColor = _presetCoverColors.first;

    final subjects = widget.studyPlan?.subjects ?? [];

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.note_add_rounded,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                'New Digital Notebook',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Input
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Notebook Title *',
                      hintText: 'e.g. Chapter 4: Capital Assets Notes',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Description
                  TextField(
                    controller: descController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      hintText: 'Key formulas, revision summaries & sketches',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Subject selector (if plan has subjects)
                  if (subjects.isNotEmpty) ...[
                    Text(
                      'Link to Subject',
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String?>(
                      initialValue: selectedSubId,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('General / No Subject'),
                        ),
                        ...subjects.map((sub) => DropdownMenuItem<String?>(
                              value: sub.id,
                              child: Text(sub.name,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            )),
                      ],
                      onChanged: (val) {
                        setDialogState(() {
                          selectedSubId = val;
                          if (val != null) {
                            final match =
                                subjects.firstWhere((s) => s.id == val);
                            selectedSubName = match.name;
                            selectedChapId = null;
                            selectedChapTitle = null;
                          } else {
                            selectedSubName = null;
                            selectedChapId = null;
                            selectedChapTitle = null;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    // Chapter selector if subject chosen
                    if (selectedSubId != null) ...[
                      Builder(builder: (ctx) {
                        final currentSub =
                            subjects.firstWhere((s) => s.id == selectedSubId);
                        if (currentSub.chapters.isNotEmpty) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Link to Chapter (optional)',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<String?>(
                                initialValue: selectedChapId,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('Entire Subject'),
                                  ),
                                  ...currentSub.chapters.map(
                                    (chap) => DropdownMenuItem<String?>(
                                      value: chap.id,
                                      child: Text(chap.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  ),
                                ],
                                onChanged: (cId) {
                                  setDialogState(() {
                                    selectedChapId = cId;
                                    if (cId != null) {
                                      selectedChapTitle = currentSub.chapters
                                          .firstWhere((c) => c.id == cId)
                                          .title;
                                    } else {
                                      selectedChapTitle = null;
                                    }
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                            ],
                          );
                        }
                        return const SizedBox.shrink();
                      }),
                    ],
                  ],

                  // Cover Color Picker
                  Text(
                    'Cover Pastel Color',
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    children: _presetCoverColors.map((color) {
                      final isSelected = selectedColor == color;
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() => selectedColor = color);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? Colors.black87
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.45),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    )
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 16)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Tags
                  TextField(
                    controller: tagsController,
                    decoration: const InputDecoration(
                      labelText: 'Tags (comma separated)',
                      hintText: 'theory, formulas, exam-focus',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  // Linked video preview indicator
                  if (prefilledVideoTitle != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.video_library_rounded,
                              color: Colors.red, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Linked Video: $prefilledVideoTitle',
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.red.shade900,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                if (titleController.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Create & Open'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          ],
        ),
      ),
    );

    if (ok == true && titleController.text.trim().isNotEmpty) {
      final tags = tagsController.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final newNotebook = Notebook(
        id: 'nb_${DateTime.now().millisecondsSinceEpoch}',
        title: titleController.text.trim(),
        description: descController.text.trim().isEmpty
            ? null
            : descController.text.trim(),
        category: selectedCategory,
        subjectId: selectedSubId,
        subjectName: selectedSubName,
        chapterId: selectedChapId,
        chapterTitle: selectedChapTitle,
        linkedVideoId: prefilledVideoId,
        linkedVideoTitle: prefilledVideoTitle,
        coverColorValue: selectedColor.toARGB32(),
        tags: tags,
        pages: [
          NotePage(
            id: 'page_${DateTime.now().millisecondsSinceEpoch}_1',
            pageNumber: 1,
            title: 'Overview',
            content:
                '# ${titleController.text.trim()}\n\nWrite your notes or sketch diagrams here...',
          ),
        ],
      );

      await StorageService.saveNotebook(newNotebook);
      await _loadNotebooks();
      widget.onPlanUpdated?.call();

      if (mounted) {
        _openNotebook(newNotebook);
      }
    }
  }

  Future<void> _toggleFavorite(Notebook notebook) async {
    notebook.isFavorite = !notebook.isFavorite;
    await StorageService.saveNotebook(notebook);
    setState(() {});
  }

  Future<void> _deleteNotebookWithConfirm(Notebook notebook) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete "${notebook.title}"?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: const Text(
          'This will permanently delete this notebook and all written pages, drawings, and formulas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await StorageService.deleteNotebook(notebook.id);
      await _loadNotebooks();
      widget.onPlanUpdated?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final isTablet = screenWidth >= 680 && screenWidth < 1024;

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadNotebooks,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 32 : (isTablet ? 20 : 16),
                    vertical: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. TOP HEADER & NEW NOTEBOOK CTA
                      _buildHeader(context, isDark, isDesktop),
                      const SizedBox(height: 20),

                      // 2. SEARCH & FILTER BAR
                      _buildSearchAndFilters(context, isDark),
                      const SizedBox(height: 24),

                      // 3. RECENT NOTES CAROUSEL (if available and no active search)
                      if (_searchQuery.isEmpty &&
                          _selectedCategory == 'All' &&
                          _selectedSubjectId == 'All' &&
                          !_onlyFavorites &&
                          _recentNotebooks.isNotEmpty) ...[
                        _buildRecentNotesSection(context, isDark),
                        const SizedBox(height: 28),
                      ],

                      // 4. NOTEBOOKS SECTION TITLE & COUNT
                      Row(
                        children: [
                          Text(
                            'All Notebooks',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_filteredNotebooks.length}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 5. NOTEBOOKS GRID OR EMPTY STATE
                      if (_filteredNotebooks.isEmpty)
                        _buildEmptyState(context, isDark)
                      else
                        _buildNotebooksGrid(
                            context, isDark, isDesktop, isTablet),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, bool isDesktop) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Digital Study Notes',
                          style: GoogleFonts.poppins(
                            fontSize: isDesktop ? 24 : 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.4,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        Text(
                          'Typed summaries, stylus diagrams & vector PDF export',
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
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
            ],
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: () => _showCreateNotebookDialog(),
          icon: const Icon(Icons.add_rounded, size: 20),
          label: Text(
            isDesktop ? 'New Notebook' : 'New',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
            ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 20 : 14,
              vertical: 14,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters(BuildContext context, bool isDark) {
    final categories = _availableCategories;
    final subjects = widget.studyPlan?.subjects ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Input
        TextField(
          controller: _searchController,
          onChanged: (val) => setState(() => _searchQuery = val),
          decoration: InputDecoration(
            hintText:
                'Search notebook titles, topics, tags or notes content...',
            hintStyle: GoogleFonts.poppins(
              fontSize: 13,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
            prefixIcon: const Icon(Icons.search_rounded,
                color: AppColors.primary, size: 22),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: isDark ? AppColors.cardDark : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 12),

        // Filter Chips Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Favorites Only Pill
              FilterChip(
                selected: _onlyFavorites,
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _onlyFavorites
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 15,
                      color: _onlyFavorites ? Colors.amber : null,
                    ),
                    const SizedBox(width: 4),
                    const Text('Favorites'),
                  ],
                ),
                onSelected: (val) => setState(() => _onlyFavorites = val),
                backgroundColor: isDark ? AppColors.cardDark : Colors.white,
                selectedColor:
                    isDark ? const Color(0xFF382F62) : AppColors.pastelPurple,
                checkmarkColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: _onlyFavorites
                        ? AppColors.primary
                        : (isDark
                            ? AppColors.borderDark
                            : AppColors.borderLight),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Category Filter Pills
              ...categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedCategory = cat);
                      }
                    },
                    backgroundColor: isDark ? AppColors.cardDark : Colors.white,
                    selectedColor: isDark
                        ? const Color(0xFF382F62)
                        : AppColors.pastelPurple,
                    labelStyle: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? AppColors.primary
                          : (isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primary
                            : (isDark
                                ? AppColors.borderDark
                                : AppColors.borderLight),
                      ),
                    ),
                  ),
                );
              }),

              // Subject Dropdown filter (if subjects exist)
              if (subjects.isNotEmpty) ...[
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _selectedSubjectId != 'All'
                          ? AppColors.primary
                          : (isDark
                              ? AppColors.borderDark
                              : AppColors.borderLight),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedSubjectId,
                      isDense: true,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _selectedSubjectId != 'All'
                            ? AppColors.primary
                            : (isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 'All',
                          child: Text('All Subjects'),
                        ),
                        ...subjects.map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedSubjectId = val);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentNotesSection(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.history_rounded,
                size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'Recently Edited',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _recentNotebooks.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final nb = _recentNotebooks[index];
              return _buildRecentCard(context, nb, isDark);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecentCard(
      BuildContext context, Notebook notebook, bool isDark) {
    final cover = Color(notebook.coverColorValue);

    return InkWell(
      onTap: () => _openNotebook(notebook),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: cover,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    notebook.subjectName ?? notebook.category,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: cover,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (notebook.isFavorite)
                  const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
              ],
            ),
            Text(
              notebook.title,
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${notebook.totalPages} pgs · ${notebook.totalWordCount} words',
                    style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  notebook.lastEditedRelative,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotebooksGrid(
      BuildContext context, bool isDark, bool isDesktop, bool isTablet) {
    final crossAxisCount = isDesktop ? 3 : (isTablet ? 2 : 1);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 220,
      ),
      itemCount: _filteredNotebooks.length,
      itemBuilder: (context, index) {
        final notebook = _filteredNotebooks[index];
        return _buildNotebookCard(context, notebook, isDark);
      },
    );
  }

  Widget _buildNotebookCard(
      BuildContext context, Notebook notebook, bool isDark) {
    final cover = Color(notebook.coverColorValue);

    return InkWell(
      onTap: () => _openNotebook(notebook),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Color Header
            Container(
              height: 12,
              decoration: BoxDecoration(
                color: cover,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(19),
                  topRight: Radius.circular(19),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges Row & Favorite Toggle
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: cover.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          notebook.subjectName ?? notebook.category,
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: cover,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (notebook.linkedVideoId != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.play_arrow_rounded,
                                  color: Colors.red, size: 12),
                              const SizedBox(width: 2),
                              Text(
                                'Class',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red.shade900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Spacer(),

                      // Favorite Button
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        iconSize: 18,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          notebook.isFavorite
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color:
                              notebook.isFavorite ? Colors.amber : Colors.grey,
                        ),
                        onPressed: () => _toggleFavorite(notebook),
                      ),

                      const SizedBox(width: 8),

                      // Popup Menu
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        iconSize: 18,
                        constraints: const BoxConstraints(),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        onSelected: (val) {
                          if (val == 'open') {
                            _openNotebook(notebook);
                          } else if (val == 'pdf') {
                            NotesPdfService.exportNotebook(notebook: notebook);
                          } else if (val == 'delete') {
                            _deleteNotebookWithConfirm(notebook);
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'open',
                            child: Row(
                              children: [
                                Icon(Icons.edit_rounded, size: 16),
                                SizedBox(width: 8),
                                Text('Open & Edit'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'pdf',
                            child: Row(
                              children: [
                                Icon(Icons.picture_as_pdf_rounded,
                                    size: 16, color: AppColors.primary),
                                SizedBox(width: 8),
                                Text('Export PDF'),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_rounded,
                                    size: 16, color: AppColors.danger),
                                SizedBox(width: 8),
                                Text('Delete',
                                    style: TextStyle(color: AppColors.danger)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Title
                  Text(
                    notebook.title,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Description
                  Text(
                    notebook.description != null &&
                            notebook.description!.trim().isNotEmpty
                        ? notebook.description!.trim()
                        : 'No description provided.',
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 14),

                  // Stats row: pages, word count, drawing icon, last edited
                  Row(
                    children: [
                      // Pages pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF2B284D)
                              : const Color(0xFFF1EEFC),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${notebook.totalPages} pgs',
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Words
                      Text(
                        '${notebook.totalWordCount} words',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),

                      if (notebook.hasDrawings) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.draw_rounded,
                            size: 13, color: AppColors.primary),
                      ],

                      const Spacer(),

                      // Last edited
                      Text(
                        notebook.lastEditedRelative,
                        style: GoogleFonts.poppins(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              color: AppColors.primary,
              size: 44,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            _searchQuery.isNotEmpty
                ? 'No matching notes found'
                : 'No notebooks in your library yet',
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try searching with another keyword or resetting the filter chips.'
                : 'Create your first digital study notebook with rich formatted text, stylus sketches, and vector PDF exports.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () {
              if (_searchQuery.isNotEmpty) {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _selectedCategory = 'All';
                  _selectedSubjectId = 'All';
                  _onlyFavorites = false;
                });
              } else {
                _showCreateNotebookDialog();
              }
            },
            icon: Icon(
              _searchQuery.isNotEmpty
                  ? Icons.refresh_rounded
                  : Icons.add_rounded,
              size: 18,
            ),
            label: Text(
              _searchQuery.isNotEmpty
                  ? 'Reset Filters'
                  : 'Create First Notebook',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }
}

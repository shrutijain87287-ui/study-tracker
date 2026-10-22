import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/note_model.dart';
import '../services/notes_pdf_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/drawing_canvas.dart';
import '../widgets/rich_notes_editor.dart';

enum EditorMode { text, drawing, split }

class NotebookEditorScreen extends StatefulWidget {
  final Notebook notebook;
  final VoidCallback? onNotebookUpdated;

  const NotebookEditorScreen({
    super.key,
    required this.notebook,
    this.onNotebookUpdated,
  });

  @override
  State<NotebookEditorScreen> createState() => _NotebookEditorScreenState();
}

class _NotebookEditorScreenState extends State<NotebookEditorScreen> {
  late Notebook _notebook;
  int _currentPageIndex = 0;
  EditorMode _editorMode = EditorMode.text;
  bool _isZenMode = false;

  late DrawingCanvasController _drawingController;
  Timer? _saveDebounceTimer;
  bool _isSaving = false;

  NotePage get _currentPage {
    if (_currentPageIndex < 0 || _currentPageIndex >= _notebook.pages.length) {
      _currentPageIndex = 0;
    }
    return _notebook.pages[_currentPageIndex];
  }

  @override
  void initState() {
    super.initState();
    _notebook = widget.notebook;
    if (_notebook.pages.isEmpty) {
      _notebook.pages.add(NotePage(
        id: 'page_${DateTime.now().millisecondsSinceEpoch}',
        pageNumber: 1,
        title: 'Page 1',
        content: '',
      ));
    }
    _initDrawingController();
  }

  void _initDrawingController() {
    _drawingController = DrawingCanvasController(
      initialStrokes: _currentPage.drawingStrokes,
      backgroundStyle: _currentPage.backgroundStyle,
    );

    _drawingController.onStrokesChanged = () {
      _currentPage.drawingStrokes = List.from(_drawingController.strokes);
      _currentPage.backgroundStyle = _drawingController.backgroundStyle;
      _scheduleAutoSave();
    };
  }

  @override
  void dispose() {
    _saveDebounceTimer?.cancel();
    _drawingController.dispose();
    super.dispose();
  }

  void _scheduleAutoSave() {
    if (mounted && !_isSaving) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isSaving) {
          setState(() => _isSaving = true);
        }
      });
    }
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(const Duration(milliseconds: 900), () async {
      await _persistNotebook();
    });
  }

  Future<void> _persistNotebook() async {
    _notebook.updatedAt = DateTime.now();
    _currentPage.updatedAt = DateTime.now();
    await StorageService.saveNotebook(_notebook);
    widget.onNotebookUpdated?.call();

    if (mounted) {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _switchToPage(int newIndex) {
    if (newIndex == _currentPageIndex) return;

    // Save current page state
    _currentPage.drawingStrokes = List.from(_drawingController.strokes);
    _currentPage.backgroundStyle = _drawingController.backgroundStyle;
    _persistNotebook();

    setState(() {
      _currentPageIndex = newIndex;
      _drawingController.dispose();
      _initDrawingController();
    });
  }

  void _addNewPage() {
    final newPageNumber = _notebook.pages.length + 1;
    final newPage = NotePage(
      id: 'page_${DateTime.now().millisecondsSinceEpoch}_$newPageNumber',
      pageNumber: newPageNumber,
      title: 'Page $newPageNumber',
      content: '',
      backgroundStyle: _currentPage.backgroundStyle,
    );

    setState(() {
      _notebook.pages.add(newPage);
      _switchToPage(_notebook.pages.length - 1);
    });
    _persistNotebook();
  }

  Future<void> _renameCurrentPage() async {
    final titleController = TextEditingController(text: _currentPage.title);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.edit_note_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('Rename Page ${_currentPage.pageNumber}',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ],
        ),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Page Title',
            hintText: 'e.g. Section 1: Core Theorems',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (ok == true && titleController.text.trim().isNotEmpty) {
      setState(() {
        _currentPage.title = titleController.text.trim();
      });
      _persistNotebook();
    }
  }

  Future<void> _deleteCurrentPage() async {
    if (_notebook.pages.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A notebook must contain at least one page.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Page ${_currentPage.pageNumber}?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete "${_currentPage.title.isEmpty ? 'Page ${_currentPage.pageNumber}' : _currentPage.title}"? This action cannot be undone.',
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
      setState(() {
        _notebook.pages.removeAt(_currentPageIndex);
        // Renumber pages
        for (int i = 0; i < _notebook.pages.length; i++) {
          _notebook.pages[i].pageNumber = i + 1;
        }
        if (_currentPageIndex >= _notebook.pages.length) {
          _currentPageIndex = _notebook.pages.length - 1;
        }
        _drawingController.dispose();
        _initDrawingController();
      });
      _persistNotebook();
    }
  }

  Future<void> _renameNotebook() async {
    final titleController = TextEditingController(text: _notebook.title);
    final descController =
        TextEditingController(text: _notebook.description ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.drive_file_rename_outline_rounded,
                color: AppColors.primary),
            const SizedBox(width: 8),
            Text('Notebook Details',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Notebook Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (ok == true && titleController.text.trim().isNotEmpty) {
      setState(() {
        _notebook.title = titleController.text.trim();
        _notebook.description = descController.text.trim().isEmpty
            ? null
            : descController.text.trim();
      });
      _persistNotebook();
    }
  }

  void _toggleFavorite() {
    setState(() {
      _notebook.isFavorite = !_notebook.isFavorite;
    });
    _persistNotebook();
  }

  void _exportPdf() {
    // Ensure all changes are committed
    _currentPage.drawingStrokes = List.from(_drawingController.strokes);
    _currentPage.backgroundStyle = _drawingController.backgroundStyle;
    _persistNotebook();

    NotesPdfService.exportNotebook(
      notebook: _notebook,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 960;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _currentPage.drawingStrokes = List.from(_drawingController.strokes);
          _currentPage.backgroundStyle = _drawingController.backgroundStyle;
          _persistNotebook();
        }
      },
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        appBar: _isZenMode ? null : _buildAppBar(context, isDark, isWide),
        body: Stack(
          children: [
            Column(
              children: [
                // Linked Video Banner (if attached to YouTube class)
                if (!_isZenMode && _notebook.linkedVideoId != null)
                  _buildLinkedClassBanner(context, isDark),

                // Main Editor Area
                Expanded(
                  child: _buildEditorContent(context, isDark, isWide),
                ),

                // Bottom Multi-page strip
                if (!_isZenMode) _buildPagesStrip(context, isDark),
              ],
            ),
            if (_isZenMode)
              Positioned(
                top: 16,
                right: 16,
                child: FilledButton.tonalIcon(
                  onPressed: () => setState(() => _isZenMode = false),
                  icon: const Icon(Icons.fullscreen_exit_rounded, size: 16),
                  label: const Text('Exit Zen Mode',
                      style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        isDark ? const Color(0xFF2C2448) : Colors.white,
                    elevation: 4,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, bool isDark, bool isWide) {
    return AppBar(
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0.5,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        tooltip: 'Back to Library',
        onPressed: () {
          _currentPage.drawingStrokes = List.from(_drawingController.strokes);
          _currentPage.backgroundStyle = _drawingController.backgroundStyle;
          _persistNotebook();
          Navigator.pop(context);
        },
      ),
      titleSpacing: 0,
      title: InkWell(
        onTap: _renameNotebook,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      _notebook.title,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.edit_rounded,
                    size: 14,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _notebook.subjectName ?? _notebook.category,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildSaveStatusIndicator(isDark),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        // Mode Switcher (Text | Canvas | Split)
        _buildModeSelector(isDark, isWide),

        const SizedBox(width: 4),

        // Favorite Toggle
        IconButton(
          icon: Icon(
            _notebook.isFavorite
                ? Icons.star_rounded
                : Icons.star_outline_rounded,
            color: _notebook.isFavorite ? Colors.amber : null,
          ),
          tooltip: _notebook.isFavorite ? 'Remove Favorite' : 'Mark Favorite',
          onPressed: _toggleFavorite,
        ),

        // PDF Export Button
        IconButton(
          icon: const Icon(Icons.picture_as_pdf_rounded),
          tooltip: 'Export as PDF',
          color: AppColors.primary,
          onPressed: _exportPdf,
        ),

        // Menu Options
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onSelected: (value) {
            switch (value) {
              case 'rename':
                _renameNotebook();
                break;
              case 'rename_page':
                _renameCurrentPage();
                break;
              case 'delete_page':
                _deleteCurrentPage();
                break;
              case 'export_pdf':
                _exportPdf();
                break;
              case 'delete_notebook':
                _confirmDeleteNotebook();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'rename',
              child: Row(
                children: [
                  Icon(Icons.edit_rounded, size: 18),
                  SizedBox(width: 10),
                  Text('Notebook Info'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'rename_page',
              child: Row(
                children: [
                  Icon(Icons.edit_note_rounded, size: 18),
                  SizedBox(width: 10),
                  Text('Rename Current Page'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete_page',
              child: Row(
                children: [
                  Icon(Icons.delete_outline_rounded,
                      size: 18, color: AppColors.danger),
                  SizedBox(width: 10),
                  Text('Delete Current Page',
                      style: TextStyle(color: AppColors.danger)),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'export_pdf',
              child: Row(
                children: [
                  Icon(Icons.picture_as_pdf_rounded,
                      size: 18, color: AppColors.primary),
                  SizedBox(width: 10),
                  Text('Export PDF Document'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'delete_notebook',
              child: Row(
                children: [
                  Icon(Icons.delete_forever_rounded,
                      size: 18, color: AppColors.danger),
                  SizedBox(width: 10),
                  Text('Delete Entire Notebook',
                      style: TextStyle(color: AppColors.danger)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildSaveStatusIndicator(bool isDark) {
    if (_isSaving) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
          const SizedBox(width: 4),
          Text(
            'Saving...',
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.amber.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_rounded,
            size: 11, color: AppColors.success),
        const SizedBox(width: 3),
        Text(
          'Saved',
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: AppColors.success,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildModeSelector(bool isDark, bool isWide) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF232042) : const Color(0xFFF1EEFC),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModeButton(
            icon: Icons.article_rounded,
            label: isWide ? 'Text' : null,
            tooltip: 'Rich Text Notes',
            mode: EditorMode.text,
            isDark: isDark,
          ),
          _buildModeButton(
            icon: Icons.draw_rounded,
            label: isWide ? 'Canvas' : null,
            tooltip: 'Handwriting & Drawing',
            mode: EditorMode.drawing,
            isDark: isDark,
          ),
          if (isWide)
            _buildModeButton(
              icon: Icons.vertical_split_rounded,
              label: 'Split',
              tooltip: 'Side by Side View',
              mode: EditorMode.split,
              isDark: isDark,
            ),
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required IconData icon,
    required String? label,
    required String tooltip,
    required EditorMode mode,
    required bool isDark,
  }) {
    final isSelected = _editorMode == mode;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () {
          setState(() {
            _editorMode = mode;
          });
        },
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(
            horizontal: label != null ? 10 : 8,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : AppColors.textSecondaryLight),
              ),
              if (label != null) ...[
                const SizedBox(width: 4),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isDark
                            ? Colors.white70
                            : AppColors.textSecondaryLight),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinkedClassBanner(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C243B) : const Color(0xFFFFF0F3),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF3F3050) : const Color(0xFFFFD6E0),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.red.shade600,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.play_arrow_rounded,
                color: Colors.white, size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Linked Class: ${_notebook.linkedVideoTitle ?? 'YouTube Class'}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color:
                    isDark ? const Color(0xFFFF9BBB) : const Color(0xFFC2185B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_notebook.subjectName != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _notebook.subjectName!,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEditorContent(BuildContext context, bool isDark, bool isWide) {
    switch (_editorMode) {
      case EditorMode.text:
        return RichNotesEditor(
          key: ValueKey('text_${_currentPage.id}'),
          initialTitle: _currentPage.title,
          initialContent: _currentPage.content,
          layout: _currentPage.layout,
          tables: _currentPage.tables,
          images: _currentPage.images,
          isZenMode: _isZenMode,
          onToggleZenMode: (val) => setState(() => _isZenMode = val),
          onLayoutChanged: (layout) {
            _currentPage.layout = layout;
            _scheduleAutoSave();
          },
          onTablesChanged: (tables) {
            _currentPage.tables = List.from(tables);
            _scheduleAutoSave();
          },
          onImagesChanged: (images) {
            _currentPage.images = List.from(images);
            _scheduleAutoSave();
          },
          onAutoSave: (title, content) {
            _currentPage.title = title;
            _currentPage.content = content;
            if (_notebook.pages.length <= 1 ||
                _notebook.title == 'Untitled Note' ||
                _notebook.title.isEmpty) {
              if (title.trim().isNotEmpty && _notebook.title != title.trim()) {
                _notebook.title = title.trim();
                if (mounted) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {});
                    }
                  });
                }
              }
            }
            _scheduleAutoSave();
          },
          showCanvasToggle: true,
          onToggleCanvas: () {
            setState(() => _editorMode = EditorMode.drawing);
          },
        );

      case EditorMode.drawing:
        return DrawingCanvasWidget(
          key: ValueKey('canvas_${_currentPage.id}'),
          controller: _drawingController,
          onClearRequest: () {
            _drawingController.clear();
            _scheduleAutoSave();
          },
        );

      case EditorMode.split:
        return Row(
          children: [
            // Left Half: Rich Text Editor
            Expanded(
              flex: 5,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(
                      color:
                          isDark ? AppColors.borderDark : AppColors.borderLight,
                      width: 1.5,
                    ),
                  ),
                ),
                child: RichNotesEditor(
                  key: ValueKey('split_text_${_currentPage.id}'),
                  initialTitle: _currentPage.title,
                  initialContent: _currentPage.content,
                  layout: _currentPage.layout,
                  tables: _currentPage.tables,
                  images: _currentPage.images,
                  isZenMode: _isZenMode,
                  onToggleZenMode: (val) => setState(() => _isZenMode = val),
                  onLayoutChanged: (layout) {
                    _currentPage.layout = layout;
                    _scheduleAutoSave();
                  },
                  onTablesChanged: (tables) {
                    _currentPage.tables = List.from(tables);
                    _scheduleAutoSave();
                  },
                  onImagesChanged: (images) {
                    _currentPage.images = List.from(images);
                    _scheduleAutoSave();
                  },
                  onAutoSave: (title, content) {
                    _currentPage.title = title;
                    _currentPage.content = content;
                    if (_notebook.pages.length <= 1 ||
                        _notebook.title == 'Untitled Note' ||
                        _notebook.title.isEmpty) {
                      if (title.trim().isNotEmpty &&
                          _notebook.title != title.trim()) {
                        _notebook.title = title.trim();
                        if (mounted) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              setState(() {});
                            }
                          });
                        }
                      }
                    }
                    _scheduleAutoSave();
                  },
                ),
              ),
            ),

            // Right Half: Drawing Canvas
            Expanded(
              flex: 5,
              child: DrawingCanvasWidget(
                key: ValueKey('split_canvas_${_currentPage.id}'),
                controller: _drawingController,
                onClearRequest: () {
                  _drawingController.clear();
                  _scheduleAutoSave();
                },
              ),
            ),
          ],
        );
    }
  }

  Widget _buildPagesStrip(BuildContext context, bool isDark) {
    final pages = _notebook.pages;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Quick Page Info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF262348) : const Color(0xFFF1EEFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_currentPageIndex + 1} / ${pages.length}',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Scrollable Pages Badges
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: pages.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final page = pages[index];
                final isSelected = index == _currentPageIndex;
                final hasStrokes = page.drawingStrokes.isNotEmpty;
                final hasText = page.content.trim().isNotEmpty;

                return InkWell(
                  onTap: () => _switchToPage(index),
                  onLongPress: () {
                    _switchToPage(index);
                    _renameCurrentPage();
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : (isDark
                              ? const Color(0xFF232042)
                              : const Color(0xFFF6F4FC)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : (isDark
                                ? const Color(0xFF353060)
                                : const Color(0xFFE5DFF5)),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          page.title.isEmpty
                              ? 'Page ${page.pageNumber}'
                              : page.title,
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : (isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight),
                          ),
                        ),
                        if (hasText || hasStrokes) ...[
                          const SizedBox(width: 4),
                          if (hasText)
                            Icon(
                              Icons.article_outlined,
                              size: 11,
                              color: isSelected ? Colors.white70 : Colors.grey,
                            ),
                          if (hasStrokes)
                            Icon(
                              Icons.gesture_rounded,
                              size: 11,
                              color: isSelected ? Colors.white70 : Colors.grey,
                            ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(width: 8),

          // Add Page Button
          OutlinedButton.icon(
            onPressed: _addNewPage,
            icon: const Icon(Icons.add_rounded, size: 15),
            label: const Text('Add Page'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary, width: 1.2),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              textStyle: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteNotebook() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete "${_notebook.title}"?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: const Text(
          'This will permanently delete this entire notebook and all of its pages and drawings. Are you sure?',
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

    if (confirmed == true && mounted) {
      await StorageService.deleteNotebook(_notebook.id);
      widget.onNotebookUpdated?.call();
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }
}

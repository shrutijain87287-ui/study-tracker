import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/note_model.dart';
import '../theme/app_theme.dart';
import 'document_image_widget.dart';
import 'document_table_widget.dart';

/// Custom TextEditingController that formats markdown headings, bold, italic,
/// underline, strikethrough, highlights, lists, checklists, callouts, and math live.
class RichNotesTextEditingController extends TextEditingController {
  String fontFamily;
  double fontSize;
  double lineSpacing;

  RichNotesTextEditingController({
    super.text,
    this.fontFamily = 'Poppins',
    this.fontSize = 15.0,
    this.lineSpacing = 1.6,
  });

  TextStyle _getBaseStyle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    switch (fontFamily) {
      case 'Roboto':
        return GoogleFonts.roboto(
            fontSize: fontSize, height: lineSpacing, color: color);
      case 'Merriweather':
        return GoogleFonts.merriweather(
            fontSize: fontSize, height: lineSpacing, color: color);
      case 'JetBrains Mono':
        return GoogleFonts.jetBrainsMono(
            fontSize: fontSize, height: lineSpacing, color: color);
      case 'Poppins':
      default:
        return GoogleFonts.poppins(
            fontSize: fontSize, height: lineSpacing, color: color);
    }
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? _getBaseStyle(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? const Color(0xFF9D88FD) : AppColors.primary;
    final codeBg = isDark ? const Color(0xFF2C2854) : const Color(0xFFF1EDFD);

    final lines = text.split('\n');
    final List<TextSpan> lineSpans = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final isLastLine = i == lines.length - 1;
      final lineEnd = isLastLine ? '' : '\n';

      // 1. Heading 1 (# ...)
      if (line.startsWith('# ')) {
        lineSpans.add(TextSpan(
          text: line + lineEnd,
          style: baseStyle.copyWith(
            fontSize: fontSize + 8,
            fontWeight: FontWeight.w800,
            color: primaryColor,
            letterSpacing: -0.4,
          ),
        ));
        continue;
      }

      // 2. Heading 2 (## ...)
      if (line.startsWith('## ')) {
        lineSpans.add(TextSpan(
          text: line + lineEnd,
          style: baseStyle.copyWith(
            fontSize: fontSize + 4,
            fontWeight: FontWeight.w700,
            color: primaryColor,
          ),
        ));
        continue;
      }

      // 3. Heading 3 (### ...)
      if (line.startsWith('### ')) {
        lineSpans.add(TextSpan(
          text: line + lineEnd,
          style: baseStyle.copyWith(
            fontSize: fontSize + 2,
            fontWeight: FontWeight.w600,
            color: primaryColor,
          ),
        ));
        continue;
      }

      // 4. Study Callout: [!NOTE], [!WARNING], [!TIP], [!IMPORTANT]
      if (line.startsWith('> [!NOTE]') ||
          line.startsWith('> [!TIP]') ||
          line.startsWith('> [!WARNING]') ||
          line.startsWith('> [!IMPORTANT]')) {
        Color calloutColor = primaryColor;
        if (line.contains('[!WARNING]')) {
          calloutColor = Colors.orange.shade700;
        } else if (line.contains('[!TIP]')) {
          calloutColor = Colors.teal.shade700;
        } else if (line.contains('[!IMPORTANT]')) {
          calloutColor = Colors.red.shade700;
        }

        lineSpans.add(TextSpan(
          text: line + lineEnd,
          style: baseStyle.copyWith(
            fontWeight: FontWeight.w600,
            color: calloutColor,
            backgroundColor: calloutColor.withValues(alpha: 0.12),
          ),
        ));
        continue;
      }

      // 5. Blockquote (> ...)
      if (line.startsWith('> ')) {
        lineSpans.add(TextSpan(
          text: line + lineEnd,
          style: baseStyle.copyWith(
            fontStyle: FontStyle.italic,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ));
        continue;
      }

      // 6. Checklist: - [ ] or - [x]
      if (line.startsWith('- [ ] ')) {
        lineSpans.add(TextSpan(
          children: [
            TextSpan(
              text: '☐ ',
              style: baseStyle.copyWith(
                  fontWeight: FontWeight.bold, color: primaryColor),
            ),
            TextSpan(
              text: line.substring(6) + lineEnd,
              style: baseStyle,
            ),
          ],
        ));
        continue;
      } else if (line.startsWith('- [x] ') || line.startsWith('- [X] ')) {
        lineSpans.add(TextSpan(
          children: [
            TextSpan(
              text: '☑ ',
              style: baseStyle.copyWith(
                  fontWeight: FontWeight.bold, color: AppColors.success),
            ),
            TextSpan(
              text: line.substring(6) + lineEnd,
              style: baseStyle.copyWith(
                decoration: TextDecoration.lineThrough,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ],
        ));
        continue;
      }

      // 7. Inline Formatting
      lineSpans.add(_parseInlineMarkdown(
        line + lineEnd,
        baseStyle,
        primaryColor,
        codeBg,
      ));
    }

    return TextSpan(children: lineSpans);
  }

  TextSpan _parseInlineMarkdown(
    String line,
    TextStyle baseStyle,
    Color primaryColor,
    Color codeBg,
  ) {
    final List<InlineSpan> spans = [];

    // Supports: **bold**, *italic*, __underline__, ~~strike~~, ==highlight==, `code`, $math$, [label](url), • bullets, numbers
    final regExp = RegExp(
      r'(\*\*[^*]+\*\*)|(\*[^*]+\*)|(__[^_]+__)|(~~[^~]+~~)|(==[^=]+==)|(`[^`]+`)|(\$[^$]+\$)|(\[[^\]]+\]\([^)]+\))|(^•\s)|(^\d+\.\s)',
    );

    int lastIndex = 0;
    for (final match in regExp.allMatches(line)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: line.substring(lastIndex, match.start),
          style: baseStyle,
        ));
      }

      final matchedText = match.group(0)!;

      if (matchedText.startsWith('**') && matchedText.endsWith('**')) {
        spans.add(TextSpan(
          text: matchedText,
          style: baseStyle.copyWith(
              fontWeight: FontWeight.bold, color: primaryColor),
        ));
      } else if (matchedText.startsWith('__') && matchedText.endsWith('__')) {
        spans.add(TextSpan(
          text: matchedText,
          style: baseStyle.copyWith(
            decoration: TextDecoration.underline,
            decorationColor: primaryColor,
          ),
        ));
      } else if (matchedText.startsWith('~~') && matchedText.endsWith('~~')) {
        spans.add(TextSpan(
          text: matchedText,
          style: baseStyle.copyWith(
            decoration: TextDecoration.lineThrough,
            color: baseStyle.color?.withValues(alpha: 0.6),
          ),
        ));
      } else if (matchedText.startsWith('==') && matchedText.endsWith('==')) {
        spans.add(TextSpan(
          text: matchedText,
          style: baseStyle.copyWith(
            backgroundColor: const Color(0xFFFFF59D), // Warm highlighter yellow
            color: const Color(0xFF2E2600),
            fontWeight: FontWeight.w600,
          ),
        ));
      } else if (matchedText.startsWith('*') && matchedText.endsWith('*')) {
        spans.add(TextSpan(
          text: matchedText,
          style: baseStyle.copyWith(fontStyle: FontStyle.italic),
        ));
      } else if (matchedText.startsWith('`') && matchedText.endsWith('`')) {
        spans.add(TextSpan(
          text: matchedText,
          style: baseStyle.copyWith(
            fontFamily: 'monospace',
            backgroundColor: codeBg,
            fontSize:
                baseStyle.fontSize != null ? baseStyle.fontSize! * 0.9 : 13,
          ),
        ));
      } else if (matchedText.startsWith('\$') && matchedText.endsWith('\$')) {
        // LaTeX math formula span
        spans.add(TextSpan(
          text: matchedText,
          style: baseStyle.copyWith(
            fontStyle: FontStyle.italic,
            color: const Color(0xFF0D9488), // Teal for math
            backgroundColor: const Color(0xFFCCFBF1).withValues(alpha: 0.4),
          ),
        ));
      } else if (matchedText.startsWith('[') && matchedText.contains('](')) {
        // Link
        spans.add(TextSpan(
          text: matchedText,
          style: baseStyle.copyWith(
            color: const Color(0xFF2563EB),
            decoration: TextDecoration.underline,
          ),
        ));
      } else if (matchedText.startsWith('•')) {
        spans.add(TextSpan(
          text: matchedText,
          style: baseStyle.copyWith(
              fontWeight: FontWeight.bold, color: primaryColor),
        ));
      } else {
        spans.add(TextSpan(
          text: matchedText,
          style: baseStyle.copyWith(
              fontWeight: FontWeight.bold, color: primaryColor),
        ));
      }

      lastIndex = match.end;
    }

    if (lastIndex < line.length) {
      spans.add(TextSpan(
        text: line.substring(lastIndex),
        style: baseStyle,
      ));
    }

    return TextSpan(children: spans);
  }
}

/// Snapshot for text undo/redo history
class TextSnapshot {
  final String text;
  final TextSelection selection;

  const TextSnapshot({
    required this.text,
    required this.selection,
  });
}

enum RibbonTab {
  home,
  insert,
  layout,
  review,
}

/// Upgraded Microsoft Word-like Document Editor with Ribbon Toolbar,
/// authentic paper sheet layout, embedded tables, embedded images,
/// LaTeX equations, study callouts, and live auto-save status.
class RichNotesEditor extends StatefulWidget {
  final String initialTitle;
  final String initialContent;
  final Function(String title, String content) onAutoSave;
  final VoidCallback? onToggleCanvas;
  final bool showCanvasToggle;
  final NotePageLayout layout;
  final List<NoteTable> tables;
  final List<NoteImageItem> images;
  final ValueChanged<NotePageLayout>? onLayoutChanged;
  final ValueChanged<List<NoteTable>>? onTablesChanged;
  final ValueChanged<List<NoteImageItem>>? onImagesChanged;
  final bool isZenMode;
  final ValueChanged<bool>? onToggleZenMode;

  const RichNotesEditor({
    super.key,
    required this.initialTitle,
    required this.initialContent,
    required this.onAutoSave,
    this.onToggleCanvas,
    this.showCanvasToggle = false,
    this.layout = const NotePageLayout(),
    this.tables = const [],
    this.images = const [],
    this.onLayoutChanged,
    this.onTablesChanged,
    this.onImagesChanged,
    this.isZenMode = false,
    this.onToggleZenMode,
  });

  @override
  State<RichNotesEditor> createState() => _RichNotesEditorState();
}

class _RichNotesEditorState extends State<RichNotesEditor> {
  late TextEditingController _titleController;
  late RichNotesTextEditingController _bodyController;
  final FocusNode _bodyFocusNode = FocusNode();

  final List<TextSnapshot> _undoStack = [];
  final List<TextSnapshot> _redoStack = [];

  RibbonTab _activeRibbonTab = RibbonTab.home;
  TextAlign _alignment = TextAlign.left;
  late NotePageLayout _layout;
  late List<NoteTable> _tables;
  late List<NoteImageItem> _images;

  // Search & Replace state
  bool _showFindReplaceBar = false;
  final TextEditingController _findController = TextEditingController();
  final TextEditingController _replaceController = TextEditingController();
  int _searchMatchCount = 0;
  int _currentMatchIndex = 0;
  final List<int> _matchIndices = [];

  Timer? _debounceTimer;
  bool _isSaving = false;
  DateTime? _lastSavedAt;

  @override
  void initState() {
    super.initState();
    _layout = widget.layout;
    _tables = List.from(widget.tables);
    _images = List.from(widget.images);

    _titleController = TextEditingController(text: widget.initialTitle);
    _bodyController = RichNotesTextEditingController(
      text: widget.initialContent,
      fontFamily: _layout.fontFamily,
      fontSize: _layout.fontSize,
      lineSpacing: _layout.lineSpacing,
    );

    _recordSnapshot();

    _titleController.addListener(_onTextChanged);
    _bodyController.addListener(_onTextChanged);
    _findController.addListener(_performSearch);
  }

  @override
  void didUpdateWidget(covariant RichNotesEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTitle != widget.initialTitle &&
        _titleController.text != widget.initialTitle) {
      _titleController.text = widget.initialTitle;
    }
    if (oldWidget.initialContent != widget.initialContent &&
        _bodyController.text != widget.initialContent) {
      _bodyController.text = widget.initialContent;
      _undoStack.clear();
      _redoStack.clear();
      _recordSnapshot();
    }
    if (oldWidget.layout != widget.layout) {
      setState(() {
        _layout = widget.layout;
        _bodyController.fontFamily = _layout.fontFamily;
        _bodyController.fontSize = _layout.fontSize;
        _bodyController.lineSpacing = _layout.lineSpacing;
      });
    }
    if (oldWidget.tables != widget.tables) {
      setState(() {
        _tables = List.from(widget.tables);
      });
    }
    if (oldWidget.images != widget.images) {
      setState(() {
        _images = List.from(widget.images);
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    widget.onAutoSave(_titleController.text, _bodyController.text);
    _titleController.dispose();
    _bodyController.dispose();
    _bodyFocusNode.dispose();
    _findController.dispose();
    _replaceController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      _isSaving = true;
    });

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 750), () {
      _flushSave();
      _recordSnapshot();
    });
  }

  void _flushSave() {
    widget.onAutoSave(_titleController.text, _bodyController.text);
    if (mounted) {
      setState(() {
        _isSaving = false;
        _lastSavedAt = DateTime.now();
      });
    }
  }

  void _recordSnapshot() {
    final currentText = _bodyController.text;
    if (_undoStack.isNotEmpty && _undoStack.last.text == currentText) {
      return;
    }
    _undoStack.add(TextSnapshot(
      text: currentText,
      selection: _bodyController.selection,
    ));
    if (_undoStack.length > 50) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  // FORMATTING ACTIONS
  void _wrapSelection(String prefix, String suffix) {
    final sel = _bodyController.selection;
    final text = _bodyController.text;

    if (!sel.isValid) {
      final newText = '$text$prefix$suffix';
      _bodyController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: text.length + prefix.length),
      );
      return;
    }

    if (sel.isCollapsed) {
      final newText = text.replaceRange(sel.start, sel.start, '$prefix$suffix');
      _bodyController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: sel.start + prefix.length),
      );
    } else {
      final selected = sel.textInside(text);
      if (selected.startsWith(prefix) && selected.endsWith(suffix)) {
        final unwrapped =
            selected.substring(prefix.length, selected.length - suffix.length);
        final newText = text.replaceRange(sel.start, sel.end, unwrapped);
        _bodyController.value = TextEditingValue(
          text: newText,
          selection: TextSelection(
            baseOffset: sel.start,
            extentOffset: sel.start + unwrapped.length,
          ),
        );
      } else {
        final wrapped = '$prefix$selected$suffix';
        final newText = text.replaceRange(sel.start, sel.end, wrapped);
        _bodyController.value = TextEditingValue(
          text: newText,
          selection: TextSelection(
            baseOffset: sel.start,
            extentOffset: sel.start + wrapped.length,
          ),
        );
      }
    }
    _bodyFocusNode.requestFocus();
  }

  void _toggleLinePrefix(String prefix) {
    final sel = _bodyController.selection;
    final text = _bodyController.text;

    int lineStart = 0;
    if (sel.isValid && sel.start > 0) {
      final lastNewLine = text.lastIndexOf('\n', sel.start - 1);
      lineStart = lastNewLine == -1 ? 0 : lastNewLine + 1;
    }

    int lineEnd = text.indexOf('\n', lineStart);
    if (lineEnd == -1) lineEnd = text.length;

    final currentLine = text.substring(lineStart, lineEnd);

    String newLine;
    if (prefix.startsWith('#')) {
      final cleanLine = currentLine.replaceFirst(RegExp(r'^#{1,3}\s*'), '');
      if (currentLine.startsWith(prefix)) {
        newLine = cleanLine;
      } else {
        newLine = '$prefix $cleanLine';
      }
    } else if (currentLine.startsWith(prefix)) {
      newLine = currentLine.substring(prefix.length);
    } else {
      newLine = '$prefix$currentLine';
    }

    final newText = text.replaceRange(lineStart, lineEnd, newLine);
    _bodyController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: (lineStart + newLine.length).clamp(0, newText.length),
      ),
    );
    _bodyFocusNode.requestFocus();
  }

  void _indent() {
    final sel = _bodyController.selection;
    final text = _bodyController.text;
    final insertPos = sel.isValid ? sel.start : text.length;
    final newText = text.replaceRange(insertPos, insertPos, '    ');
    _bodyController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: insertPos + 4),
    );
    _bodyFocusNode.requestFocus();
  }

  void _outdent() {
    final sel = _bodyController.selection;
    final text = _bodyController.text;
    int lineStart = 0;
    if (sel.isValid && sel.start > 0) {
      final lastNewLine = text.lastIndexOf('\n', sel.start - 1);
      lineStart = lastNewLine == -1 ? 0 : lastNewLine + 1;
    }
    if (text.startsWith('    ', lineStart)) {
      final newText = text.replaceRange(lineStart, lineStart + 4, '');
      _bodyController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: (sel.start - 4).clamp(lineStart, newText.length),
        ),
      );
    }
    _bodyFocusNode.requestFocus();
  }

  void _undo() {
    if (_undoStack.length > 1) {
      final current = _undoStack.removeLast();
      _redoStack.add(current);
      final prev = _undoStack.last;
      _bodyController.value = TextEditingValue(
        text: prev.text,
        selection: prev.selection,
      );
      _flushSave();
    }
  }

  void _redo() {
    if (_redoStack.isNotEmpty) {
      final next = _redoStack.removeLast();
      _undoStack.add(next);
      _bodyController.value = TextEditingValue(
        text: next.text,
        selection: next.selection,
      );
      _flushSave();
    }
  }

  // SEARCH AND REPLACE
  void _performSearch() {
    final query = _findController.text;
    _matchIndices.clear();
    if (query.trim().isEmpty) {
      setState(() {
        _searchMatchCount = 0;
        _currentMatchIndex = 0;
      });
      return;
    }

    final body = _bodyController.text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    int index = 0;

    while (true) {
      final match = body.indexOf(lowerQuery, index);
      if (match == -1) break;
      _matchIndices.add(match);
      index = match + lowerQuery.length;
    }

    setState(() {
      _searchMatchCount = _matchIndices.length;
      if (_searchMatchCount > 0) {
        _currentMatchIndex = 0;
        _highlightCurrentMatch();
      } else {
        _currentMatchIndex = 0;
      }
    });
  }

  void _highlightCurrentMatch() {
    if (_matchIndices.isEmpty) return;
    final pos = _matchIndices[_currentMatchIndex];
    final len = _findController.text.length;
    _bodyController.selection = TextSelection(
      baseOffset: pos,
      extentOffset: pos + len,
    );
    _bodyFocusNode.requestFocus();
  }

  void _nextMatch() {
    if (_matchIndices.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _matchIndices.length;
      _highlightCurrentMatch();
    });
  }

  void _prevMatch() {
    if (_matchIndices.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex - 1 + _matchIndices.length) %
          _matchIndices.length;
      _highlightCurrentMatch();
    });
  }

  void _replaceOne() {
    if (_matchIndices.isEmpty) return;
    final pos = _matchIndices[_currentMatchIndex];
    final len = _findController.text.length;
    final replaceWith = _replaceController.text;

    final newText =
        _bodyController.text.replaceRange(pos, pos + len, replaceWith);
    _bodyController.text = newText;
    _performSearch();
  }

  void _replaceAll() {
    if (_matchIndices.isEmpty) return;
    final query = _findController.text;
    final replaceWith = _replaceController.text;
    final newText = _bodyController.text.replaceAll(query, replaceWith);
    _bodyController.text = newText;
    _performSearch();
  }

  // INSERT DIALOGS
  Future<void> _showInsertTableDialog() async {
    int rows = 3;
    int cols = 3;
    final captionController =
        TextEditingController(text: 'Study Summary Table');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.table_chart_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Insert Document Table'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: captionController,
                decoration: const InputDecoration(
                  labelText: 'Table Caption',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Rows:'),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: rows > 1
                            ? () => setDialogState(() => rows--)
                            : null,
                      ),
                      Text('$rows',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: rows < 12
                            ? () => setDialogState(() => rows++)
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Columns:'),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: cols > 1
                            ? () => setDialogState(() => cols--)
                            : null,
                      ),
                      Text('$cols',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: cols < 8
                            ? () => setDialogState(() => cols++)
                            : null,
                      ),
                    ],
                  ),
                ],
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
              child: const Text('Insert Table'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      final newTable = NoteTable.create(
        id: 'tbl_${DateTime.now().millisecondsSinceEpoch}',
        rows: rows,
        cols: cols,
        caption: captionController.text.trim().isEmpty
            ? null
            : captionController.text.trim(),
      );
      setState(() {
        _tables.add(newTable);
      });
      widget.onTablesChanged?.call(_tables);
      _flushSave();
    }
  }

  Future<void> _pickAndInsertImage() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.image,
      );

      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          final base64String = base64Encode(bytes);
          final extension = (file.extension ?? 'png').toLowerCase();
          final mime = extension == 'jpg' || extension == 'jpeg'
              ? 'image/jpeg'
              : 'image/png';
          final dataUri = 'data:$mime;base64,$base64String';

          final newImage = NoteImageItem(
            id: 'img_${DateTime.now().millisecondsSinceEpoch}',
            dataBase64: dataUri,
            caption: file.name,
            alignment: NoteImageAlignment.center,
            widthScale: 0.8,
          );

          setState(() {
            _images.add(newImage);
          });
          widget.onImagesChanged?.call(_images);
          _flushSave();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _showInsertLinkDialog() async {
    final labelController = TextEditingController();
    final urlController = TextEditingController(text: 'https://');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.link_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Insert Hyperlink'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelController,
              decoration: const InputDecoration(
                labelText: 'Display Text',
                hintText: 'e.g. Official Study Module',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'Web URL',
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
            child: const Text('Insert Link'),
          ),
        ],
      ),
    );

    if (ok == true) {
      final label = labelController.text.trim().isEmpty
          ? 'Link'
          : labelController.text.trim();
      final url = urlController.text.trim();
      final linkMarkdown = ' [$label]($url) ';
      final sel = _bodyController.selection;
      final text = _bodyController.text;
      final pos = sel.isValid ? sel.start : text.length;
      final newText = text.replaceRange(pos, pos, linkMarkdown);
      _bodyController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: pos + linkMarkdown.length),
      );
      _bodyFocusNode.requestFocus();
    }
  }

  Future<void> _showInsertEquationDialog() async {
    final eqController = TextEditingController(text: r'E = mc^2');

    final symbols = [
      r'\sqrt{x}',
      r'\frac{a}{b}',
      r'\sum_{i=1}^n',
      r'\int_{a}^{b}',
      r'\alpha',
      r'\beta',
      r'\theta',
      r'\pi',
      r'\Delta',
      r'\le',
      r'\ge',
      r'\ne',
      r'\pm',
      r'\infty'
    ];

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.functions_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Insert Math Equation / Formula'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: eqController,
                  decoration: const InputDecoration(
                    labelText: 'LaTeX Equation',
                    hintText: r'e.g. \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Quick Mathematical Symbols:',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: symbols.map((sym) {
                    return ActionChip(
                      label: Text(sym,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 11)),
                      onPressed: () {
                        setDialogState(() {
                          eqController.text = '${eqController.text} $sym';
                        });
                      },
                    );
                  }).toList(),
                ),
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
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Insert Equation'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && eqController.text.trim().isNotEmpty) {
      final formula = ' \$${eqController.text.trim()}\$ ';
      final sel = _bodyController.selection;
      final text = _bodyController.text;
      final pos = sel.isValid ? sel.start : text.length;
      final newText = text.replaceRange(pos, pos, formula);
      _bodyController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: pos + formula.length),
      );
      _bodyFocusNode.requestFocus();
    }
  }

  Future<void> _showInsertCalloutDialog() async {
    String type = 'NOTE';
    final textController = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Insert Study Callout'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'NOTE', label: Text('💡 Note')),
                  ButtonSegment(value: 'WARNING', label: Text('⚠️ Alert')),
                  ButtonSegment(value: 'TIP', label: Text('📝 Tip')),
                  ButtonSegment(value: 'IMPORTANT', label: Text('📌 Def')),
                ],
                selected: {type},
                onSelectionChanged: (val) {
                  setDialogState(() => type = val.first);
                },
              ),
              const SizedBox(height: 14),
              TextField(
                controller: textController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Callout Message',
                  hintText: type == 'NOTE'
                      ? 'Key concept or takeaway to remember...'
                      : (type == 'WARNING'
                          ? 'Common exam pitfall or trap...'
                          : 'Quick study strategy tip...'),
                  border: const OutlineInputBorder(),
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
              child: const Text('Insert Callout'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && textController.text.trim().isNotEmpty) {
      final calloutText = '\n> [!$type] ${textController.text.trim()}\n';
      final sel = _bodyController.selection;
      final text = _bodyController.text;
      final pos = sel.isValid ? sel.start : text.length;
      final newText = text.replaceRange(pos, pos, calloutText);
      _bodyController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: pos + calloutText.length),
      );
      _bodyFocusNode.requestFocus();
    }
  }

  Future<void> _showInsertCodeBlockDialog() async {
    String language = 'dart';
    final codeController = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.code_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Insert Code / Pseudocode Block'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: language,
                decoration: const InputDecoration(
                    labelText: 'Language', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(
                      value: 'dart', child: Text('Dart / Flutter')),
                  DropdownMenuItem(value: 'python', child: Text('Python')),
                  DropdownMenuItem(value: 'sql', child: Text('SQL / Database')),
                  DropdownMenuItem(
                      value: 'javascript', child: Text('JavaScript')),
                  DropdownMenuItem(
                      value: 'plaintext',
                      child: Text('Plain Text / Pseudocode')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => language = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                maxLines: 4,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Code Body',
                  hintText: '// Paste your code here...',
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
              child: const Text('Insert Code'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && codeController.text.trim().isNotEmpty) {
      final codeBlock = '\n```$language\n${codeController.text.trim()}\n```\n';
      final sel = _bodyController.selection;
      final text = _bodyController.text;
      final pos = sel.isValid ? sel.start : text.length;
      final newText = text.replaceRange(pos, pos, codeBlock);
      _bodyController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: pos + codeBlock.length),
      );
      _bodyFocusNode.requestFocus();
    }
  }

  void _insertDateTime() {
    final now = DateTime.now();
    final formatted = DateFormat('EEEE, d MMMM yyyy, h:mm a').format(now);
    final sel = _bodyController.selection;
    final text = _bodyController.text;
    final pos = sel.isValid ? sel.start : text.length;
    final newText = text.replaceRange(pos, pos, formatted);
    _bodyController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: pos + formatted.length),
    );
    _bodyFocusNode.requestFocus();
  }

  void _insertPageBreak() {
    final sel = _bodyController.selection;
    final text = _bodyController.text;
    final pos = sel.isValid ? sel.start : text.length;
    const breakText = '\n\n---\n\n';
    final newText = text.replaceRange(pos, pos, breakText);
    _bodyController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: pos + breakText.length),
    );
    _bodyFocusNode.requestFocus();
  }

  void _showStatsDialog() {
    final text = _bodyController.text;
    final words =
        text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;
    final chars = text.length;
    final charsNoSpaces = text.replaceAll(RegExp(r'\s'), '').length;
    final lines = text.split('\n').length;
    final readTimeMinutes = (words / 200).ceil();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.analytics_outlined, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Document Statistics'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatRow('Words', '$words'),
            _buildStatRow('Characters', '$chars'),
            _buildStatRow('Characters (no spaces)', '$charsNoSpaces'),
            _buildStatRow('Paragraphs / Lines', '$lines'),
            _buildStatRow('Tables inserted', '${_tables.length}'),
            _buildStatRow('Images inserted', '${_images.length}'),
            const Divider(height: 20),
            _buildStatRow('Estimated Read Time', '~ $readTimeMinutes min'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(value,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.cardDark : Colors.white;
    final pageBg = isDark ? const Color(0xFF17152B) : const Color(0xFFF3F1FA);
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Column(
      children: [
        // 1. Word-Style Ribbon Toolbar (Tabs & Control Bar)
        _buildRibbon(cardBg, borderColor, isDark),

        // 2. Interactive Find & Replace Bar (when active)
        if (_showFindReplaceBar)
          _buildFindReplaceBar(cardBg, borderColor, isDark),

        // 3. Document Paper Canvas (A4 / Letter Sheet with Margins)
        Expanded(
          child: Container(
            color: pageBg,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Center(
                child: _buildDocumentSheet(cardBg, borderColor, isDark),
              ),
            ),
          ),
        ),

        // 4. Bottom Auto-Save Status Bar
        _buildBottomStatusBar(cardBg, borderColor, textSecondary),
      ],
    );
  }

  Widget _buildRibbon(Color cardBg, Color borderColor, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(bottom: BorderSide(color: borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ribbon Tab Buttons
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, top: 4),
            child: Row(
              children: [
                _buildRibbonTabHeader(
                    'Home', RibbonTab.home, Icons.edit_note_rounded),
                _buildRibbonTabHeader('Insert', RibbonTab.insert,
                    Icons.add_circle_outline_rounded),
                _buildRibbonTabHeader('Layout', RibbonTab.layout,
                    Icons.auto_awesome_mosaic_rounded),
                _buildRibbonTabHeader(
                    'Review', RibbonTab.review, Icons.fact_check_rounded),
                const Spacer(),
                if (widget.showCanvasToggle && widget.onToggleCanvas != null)
                  FilledButton.tonalIcon(
                    onPressed: widget.onToggleCanvas,
                    icon: const Icon(Icons.draw_rounded, size: 15),
                    label: const Text('Draw Canvas',
                        style: TextStyle(fontSize: 11.5)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Ribbon Active Controls Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: _buildActiveTabControls(borderColor, isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRibbonTabHeader(String title, RibbonTab tab, IconData icon) {
    final isSelected = _activeRibbonTab == tab;
    return InkWell(
      onTap: () => setState(() => _activeRibbonTab = tab),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14, color: isSelected ? AppColors.primary : Colors.grey),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primary : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTabControls(Color borderColor, bool isDark) {
    switch (_activeRibbonTab) {
      case RibbonTab.home:
        return _buildHomeTabControls(borderColor, isDark);
      case RibbonTab.insert:
        return _buildInsertTabControls(borderColor, isDark);
      case RibbonTab.layout:
        return _buildLayoutTabControls(borderColor, isDark);
      case RibbonTab.review:
        return _buildReviewTabControls(borderColor, isDark);
    }
  }

  Widget _buildHomeTabControls(Color borderColor, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Font Family Selector
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF262340) : const Color(0xFFF3F0FD),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _layout.fontFamily,
              isDense: true,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
              items: const [
                DropdownMenuItem(value: 'Poppins', child: Text('Poppins')),
                DropdownMenuItem(value: 'Roboto', child: Text('Roboto')),
                DropdownMenuItem(
                    value: 'Merriweather', child: Text('Merriweather (Serif)')),
                DropdownMenuItem(
                    value: 'JetBrains Mono', child: Text('JetBrains (Mono)')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _layout = _layout.copyWith(fontFamily: val);
                    _bodyController.fontFamily = val;
                  });
                  widget.onLayoutChanged?.call(_layout);
                }
              },
            ),
          ),
        ),
        const SizedBox(width: 6),

        // Font Size Selector
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF262340) : const Color(0xFFF3F0FD),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<double>(
              value: _layout.fontSize,
              isDense: true,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
              items: [12.0, 14.0, 15.0, 16.0, 18.0, 20.0, 24.0].map((size) {
                return DropdownMenuItem(
                    value: size, child: Text('${size.toInt()} pt'));
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _layout = _layout.copyWith(fontSize: val);
                    _bodyController.fontSize = val;
                  });
                  widget.onLayoutChanged?.call(_layout);
                }
              },
            ),
          ),
        ),

        _buildVerticalDivider(borderColor),

        // Headings
        _buildToolbarButton(
            label: 'H1',
            tooltip: 'Heading 1',
            onTap: () => _toggleLinePrefix('# ')),
        _buildToolbarButton(
            label: 'H2',
            tooltip: 'Heading 2',
            onTap: () => _toggleLinePrefix('## ')),
        _buildToolbarButton(
            label: 'H3',
            tooltip: 'Heading 3',
            onTap: () => _toggleLinePrefix('### ')),

        _buildVerticalDivider(borderColor),

        // Bold, Italic, Underline, Strikethrough, Highlight
        _buildIconButton(
          icon: Icons.format_bold_rounded,
          tooltip: 'Bold (Ctrl/Cmd+B)',
          onTap: () => _wrapSelection('**', '**'),
        ),
        _buildIconButton(
          icon: Icons.format_italic_rounded,
          tooltip: 'Italic (Ctrl/Cmd+I)',
          onTap: () => _wrapSelection('*', '*'),
        ),
        _buildIconButton(
          icon: Icons.format_underlined_rounded,
          tooltip: 'Underline (Ctrl/Cmd+U)',
          onTap: () => _wrapSelection('__', '__'),
        ),
        _buildIconButton(
          icon: Icons.format_strikethrough_rounded,
          tooltip: 'Strikethrough (~~text~~)',
          onTap: () => _wrapSelection('~~', '~~'),
        ),
        _buildIconButton(
          icon: Icons.highlight_rounded,
          tooltip: 'Highlight (==text==)',
          onTap: () => _wrapSelection('==', '=='),
        ),

        _buildVerticalDivider(borderColor),

        // Alignment
        _buildIconButton(
          icon: Icons.format_align_left_rounded,
          tooltip: 'Align Left',
          isSelected: _alignment == TextAlign.left,
          onTap: () => setState(() => _alignment = TextAlign.left),
        ),
        _buildIconButton(
          icon: Icons.format_align_center_rounded,
          tooltip: 'Align Center',
          isSelected: _alignment == TextAlign.center,
          onTap: () => setState(() => _alignment = TextAlign.center),
        ),
        _buildIconButton(
          icon: Icons.format_align_right_rounded,
          tooltip: 'Align Right',
          isSelected: _alignment == TextAlign.right,
          onTap: () => setState(() => _alignment = TextAlign.right),
        ),
        _buildIconButton(
          icon: Icons.format_align_justify_rounded,
          tooltip: 'Justify',
          isSelected: _alignment == TextAlign.justify,
          onTap: () => setState(() => _alignment = TextAlign.justify),
        ),

        _buildVerticalDivider(borderColor),

        // Lists & Checklists
        _buildIconButton(
          icon: Icons.format_list_bulleted_rounded,
          tooltip: 'Bullet List',
          onTap: () => _toggleLinePrefix('• '),
        ),
        _buildIconButton(
          icon: Icons.format_list_numbered_rounded,
          tooltip: 'Numbered List',
          onTap: () => _toggleLinePrefix('1. '),
        ),
        _buildIconButton(
          icon: Icons.check_box_outlined,
          tooltip: 'Checklist / To-Do (- [ ] )',
          onTap: () => _toggleLinePrefix('- [ ] '),
        ),

        _buildVerticalDivider(borderColor),

        // Indent & Outdent
        _buildIconButton(
          icon: Icons.format_indent_decrease_rounded,
          tooltip: 'Decrease Indent',
          onTap: _outdent,
        ),
        _buildIconButton(
          icon: Icons.format_indent_increase_rounded,
          tooltip: 'Increase Indent',
          onTap: _indent,
        ),

        _buildVerticalDivider(borderColor),

        // Undo & Redo
        _buildIconButton(
          icon: Icons.undo_rounded,
          tooltip: 'Undo',
          onTap: _undoStack.length > 1 ? _undo : null,
        ),
        _buildIconButton(
          icon: Icons.redo_rounded,
          tooltip: 'Redo',
          onTap: _redoStack.isNotEmpty ? _redo : null,
        ),
      ],
    );
  }

  Widget _buildInsertTabControls(Color borderColor, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        FilledButton.tonalIcon(
          icon: const Icon(Icons.table_chart_rounded, size: 16),
          label: const Text('Insert Table', style: TextStyle(fontSize: 12)),
          onPressed: _showInsertTableDialog,
          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
        const SizedBox(width: 6),
        FilledButton.tonalIcon(
          icon: const Icon(Icons.image_rounded, size: 16),
          label: const Text('Upload Picture', style: TextStyle(fontSize: 12)),
          onPressed: _pickAndInsertImage,
          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
        const SizedBox(width: 6),
        FilledButton.tonalIcon(
          icon: const Icon(Icons.link_rounded, size: 16),
          label: const Text('Link', style: TextStyle(fontSize: 12)),
          onPressed: _showInsertLinkDialog,
          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
        const SizedBox(width: 6),
        FilledButton.tonalIcon(
          icon: const Icon(Icons.functions_rounded, size: 16),
          label: const Text('Math Formula', style: TextStyle(fontSize: 12)),
          onPressed: _showInsertEquationDialog,
          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
        const SizedBox(width: 6),
        FilledButton.tonalIcon(
          icon: const Icon(Icons.lightbulb_outline_rounded, size: 16),
          label: const Text('Study Callout', style: TextStyle(fontSize: 12)),
          onPressed: _showInsertCalloutDialog,
          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
        const SizedBox(width: 6),
        FilledButton.tonalIcon(
          icon: const Icon(Icons.code_rounded, size: 16),
          label: const Text('Code Block', style: TextStyle(fontSize: 12)),
          onPressed: _showInsertCodeBlockDialog,
          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
        const SizedBox(width: 6),
        FilledButton.tonalIcon(
          icon: const Icon(Icons.schedule_rounded, size: 16),
          label: const Text('Date & Time', style: TextStyle(fontSize: 12)),
          onPressed: _insertDateTime,
          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
        const SizedBox(width: 6),
        FilledButton.tonalIcon(
          icon: const Icon(Icons.horizontal_rule_rounded, size: 16),
          label: const Text('Page Break', style: TextStyle(fontSize: 12)),
          onPressed: _insertPageBreak,
          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
      ],
    );
  }

  Widget _buildLayoutTabControls(Color borderColor, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Page Size
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Size: ',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            DropdownButton<DocumentPageSize>(
              value: _layout.pageSize,
              isDense: true,
              underline: const SizedBox.shrink(),
              items: DocumentPageSize.values.map((ps) {
                return DropdownMenuItem(
                    value: ps,
                    child:
                        Text(ps.label, style: const TextStyle(fontSize: 12)));
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _layout = _layout.copyWith(pageSize: val));
                  widget.onLayoutChanged?.call(_layout);
                }
              },
            ),
          ],
        ),

        _buildVerticalDivider(borderColor),

        // Orientation
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Orientation: ',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            DropdownButton<DocumentOrientation>(
              value: _layout.orientation,
              isDense: true,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(
                    value: DocumentOrientation.portrait,
                    child: Text('Portrait', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(
                    value: DocumentOrientation.landscape,
                    child: Text('Landscape', style: TextStyle(fontSize: 12))),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _layout = _layout.copyWith(orientation: val));
                  widget.onLayoutChanged?.call(_layout);
                }
              },
            ),
          ],
        ),

        _buildVerticalDivider(borderColor),

        // Margins
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Margins: ',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            DropdownButton<DocumentMargin>(
              value: _layout.margin,
              isDense: true,
              underline: const SizedBox.shrink(),
              items: DocumentMargin.values.map((m) {
                return DropdownMenuItem(
                    value: m,
                    child: Text(m.label, style: const TextStyle(fontSize: 12)));
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _layout = _layout.copyWith(margin: val));
                  widget.onLayoutChanged?.call(_layout);
                }
              },
            ),
          ],
        ),

        _buildVerticalDivider(borderColor),

        // Line Spacing
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Spacing: ',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            DropdownButton<double>(
              value: _layout.lineSpacing,
              isDense: true,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(
                    value: 1.2,
                    child:
                        Text('Single (1.2)', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(
                    value: 1.5,
                    child: Text('1.5 Lines', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(
                    value: 1.6,
                    child:
                        Text('Standard (1.6)', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(
                    value: 2.0,
                    child:
                        Text('Double (2.0)', style: TextStyle(fontSize: 12))),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _layout = _layout.copyWith(lineSpacing: val);
                    _bodyController.lineSpacing = val;
                  });
                  widget.onLayoutChanged?.call(_layout);
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReviewTabControls(Color borderColor, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        FilledButton.tonalIcon(
          icon: const Icon(Icons.search_rounded, size: 16),
          label: Text(
              _showFindReplaceBar ? 'Hide Find & Replace' : 'Find & Replace',
              style: const TextStyle(fontSize: 12)),
          onPressed: () {
            setState(() {
              _showFindReplaceBar = !_showFindReplaceBar;
              if (_showFindReplaceBar) {
                _performSearch();
              }
            });
          },
          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
        const SizedBox(width: 8),
        FilledButton.tonalIcon(
          icon: const Icon(Icons.analytics_outlined, size: 16),
          label: const Text('Word & Doc Stats', style: TextStyle(fontSize: 12)),
          onPressed: _showStatsDialog,
          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
        const SizedBox(width: 8),
        FilledButton.tonalIcon(
          icon: Icon(
              widget.isZenMode
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded,
              size: 16),
          label: Text(widget.isZenMode ? 'Exit Zen Mode' : 'Zen Focus Mode',
              style: const TextStyle(fontSize: 12)),
          onPressed: () => widget.onToggleZenMode?.call(!widget.isZenMode),
          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
      ],
    );
  }

  Widget _buildFindReplaceBar(Color cardBg, Color borderColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          // Find input
          Expanded(
            flex: 4,
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: _findController,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Find in document...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Matches Indicator & Navigation
          Text(
            _searchMatchCount > 0
                ? '${_currentMatchIndex + 1} of $_searchMatchCount'
                : 'No matches',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _searchMatchCount > 0 ? AppColors.primary : Colors.grey,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
            onPressed: _searchMatchCount > 0 ? _prevMatch : null,
            visualDensity: VisualDensity.compact,
            tooltip: 'Previous match',
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
            onPressed: _searchMatchCount > 0 ? _nextMatch : null,
            visualDensity: VisualDensity.compact,
            tooltip: 'Next match',
          ),

          const SizedBox(width: 8),
          _buildVerticalDivider(borderColor),
          const SizedBox(width: 8),

          // Replace input
          Expanded(
            flex: 4,
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: _replaceController,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Replace with...',
                  prefixIcon: const Icon(Icons.find_replace_rounded, size: 18),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          FilledButton.tonal(
            onPressed: _searchMatchCount > 0 ? _replaceOne : null,
            child: const Text('Replace', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 4),
          FilledButton.tonal(
            onPressed: _searchMatchCount > 0 ? _replaceAll : null,
            child: const Text('Replace All', style: TextStyle(fontSize: 12)),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: () => setState(() => _showFindReplaceBar = false),
            tooltip: 'Close find bar',
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentSheet(Color cardBg, Color borderColor, bool isDark) {
    // Determine sheet width based on page size and orientation
    double? sheetWidth = _layout.pageSize.targetWidth;
    if (sheetWidth != null &&
        _layout.orientation == DocumentOrientation.landscape) {
      sheetWidth = sheetWidth * 1.35;
    }

    final marginPadding = _layout.margin.padding;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: sheetWidth ?? 820.0,
        minHeight: 480,
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
            horizontal: marginPadding, vertical: marginPadding + 8),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Document Header / Category Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sticky_note_2_outlined,
                          size: 13, color: AppColors.primary),
                      const SizedBox(width: 5),
                      Text(
                        'STUDY NOTES • ${_layout.pageSize.label.split(' ').first.toUpperCase()}',
                        style: GoogleFonts.poppins(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  DateFormat('MMM d, yyyy').format(DateTime.now()),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Title Input
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'Note Title...',
                hintStyle: GoogleFonts.poppins(
                  color: isDark ? Colors.white30 : Colors.black26,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: GoogleFonts.poppins(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 14),

            // Main Rich Text Body
            TextField(
              controller: _bodyController,
              focusNode: _bodyFocusNode,
              maxLines: null,
              textAlign: _alignment,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                hintText:
                    'Start writing your study notes here...\n\nUse the toolbar tabs above to format text, insert tables, upload images, add formulas, or switch to drawing canvas.',
                hintStyle: TextStyle(
                  color: (isDark ? Colors.white30 : Colors.black26),
                  fontSize: _layout.fontSize,
                  height: _layout.lineSpacing,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: _bodyController._getBaseStyle(context),
            ),

            // Embedded Tables
            if (_tables.isNotEmpty) ...[
              const SizedBox(height: 24),
              ..._tables.asMap().entries.map((entry) {
                final idx = entry.key;
                final tbl = entry.value;
                return DocumentTableWidget(
                  key: ValueKey('tbl_${tbl.id}'),
                  table: tbl,
                  onChanged: (updated) {
                    setState(() {
                      _tables[idx] = updated;
                    });
                    widget.onTablesChanged?.call(_tables);
                    _flushSave();
                  },
                  onDelete: () {
                    setState(() {
                      _tables.removeAt(idx);
                    });
                    widget.onTablesChanged?.call(_tables);
                    _flushSave();
                  },
                );
              }),
            ],

            // Embedded Images
            if (_images.isNotEmpty) ...[
              const SizedBox(height: 20),
              ..._images.asMap().entries.map((entry) {
                final idx = entry.key;
                final img = entry.value;
                return DocumentImageWidget(
                  key: ValueKey('img_${img.id}'),
                  imageItem: img,
                  onChanged: (updated) {
                    setState(() {
                      _images[idx] = updated;
                    });
                    widget.onImagesChanged?.call(_images);
                    _flushSave();
                  },
                  onDelete: () {
                    setState(() {
                      _images.removeAt(idx);
                    });
                    widget.onImagesChanged?.call(_images);
                    _flushSave();
                  },
                );
              }),
            ],

            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalDivider(Color borderColor) {
    return Container(
      width: 1,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: borderColor,
    );
  }

  Widget _buildToolbarButton({
    required String label,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Tooltip(
        message: tooltip,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    VoidCallback? onTap,
    bool isSelected = false,
  }) {
    return IconButton(
      icon: Icon(
        icon,
        size: 19,
        color: isSelected ? AppColors.primary : null,
      ),
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      style: isSelected
          ? IconButton.styleFrom(backgroundColor: AppColors.primaryLight)
          : null,
    );
  }

  Widget _buildBottomStatusBar(
    Color cardBg,
    Color borderColor,
    Color textSecondary,
  ) {
    final wordCount = _bodyController.text.trim().isEmpty
        ? 0
        : _bodyController.text.trim().split(RegExp(r'\s+')).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$wordCount words • ${_bodyController.text.length} chars • ${_tables.length} tables • ${_images.length} images',
            style: TextStyle(fontSize: 12, color: textSecondary),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isSaving) ...[
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Saving...',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ] else ...[
                const Icon(
                  Icons.check_circle_rounded,
                  size: 14,
                  color: AppColors.success,
                ),
                const SizedBox(width: 6),
                Text(
                  _lastSavedAt != null ? 'Saved' : 'All changes saved',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.success,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

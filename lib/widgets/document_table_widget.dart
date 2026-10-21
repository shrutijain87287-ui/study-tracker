import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/note_model.dart';
import '../theme/app_theme.dart';

class DocumentTableWidget extends StatefulWidget {
  final NoteTable table;
  final ValueChanged<NoteTable> onChanged;
  final VoidCallback onDelete;

  const DocumentTableWidget({
    super.key,
    required this.table,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<DocumentTableWidget> createState() => _DocumentTableWidgetState();
}

class _DocumentTableWidgetState extends State<DocumentTableWidget> {
  late NoteTable _table;
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _table = widget.table;
    _initControllers();
  }

  void _initControllers() {
    for (int r = 0; r < _table.rowCount; r++) {
      for (int c = 0; c < _table.colCount; c++) {
        final key = '$r-$c';
        if (!_controllers.containsKey(key)) {
          _controllers[key] =
              TextEditingController(text: _table.cells[r][c].text);
        } else {
          if (_controllers[key]!.text != _table.cells[r][c].text) {
            _controllers[key]!.text = _table.cells[r][c].text;
          }
        }
      }
    }
  }

  @override
  void didUpdateWidget(covariant DocumentTableWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.table != widget.table) {
      _table = widget.table;
      _initControllers();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _notifyChange() {
    widget.onChanged(_table);
  }

  void _addRow() {
    setState(() {
      _table.addRow();
      _initControllers();
    });
    _notifyChange();
  }

  void _removeRow() {
    if (_table.rowCount <= 1) return;
    setState(() {
      _table.removeRow(_table.rowCount - 1);
      _initControllers();
    });
    _notifyChange();
  }

  void _addColumn() {
    setState(() {
      _table.addColumn();
      _initControllers();
    });
    _notifyChange();
  }

  void _removeColumn() {
    if (_table.colCount <= 1) return;
    setState(() {
      _table.removeColumn(_table.colCount - 1);
      _initControllers();
    });
    _notifyChange();
  }

  void _toggleHeaderRow() {
    setState(() {
      final shouldBeHeader = !_table.cells[0][0].isHeader;
      for (int c = 0; c < _table.colCount; c++) {
        _table.cells[0][c].isHeader = shouldBeHeader;
      }
    });
    _notifyChange();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor =
        isDark ? const Color(0xFF3F3B66) : const Color(0xFFE2DCF5);
    final headerBg = isDark ? const Color(0xFF2C2852) : const Color(0xFFF1EEFC);
    final rowAltBg = isDark ? const Color(0xFF1F1C36) : const Color(0xFFFAFAFE);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Table Action Toolbar (Word-style table tools)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF262243) : const Color(0xFFF7F5FD),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
              border: Border(bottom: BorderSide(color: borderColor, width: 1)),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.table_chart_rounded,
                        color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Table (${_table.rowCount} × ${_table.colCount})',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    _buildActionButton(
                      icon: Icons.add_rounded,
                      label: 'Row',
                      tooltip: 'Add Row below',
                      onPressed: _addRow,
                    ),
                    _buildActionButton(
                      icon: Icons.remove_rounded,
                      label: 'Row',
                      tooltip: 'Remove last row',
                      onPressed: _table.rowCount > 1 ? _removeRow : null,
                    ),
                    _buildActionButton(
                      icon: Icons.add_rounded,
                      label: 'Col',
                      tooltip: 'Add Column to right',
                      onPressed: _addColumn,
                    ),
                    _buildActionButton(
                      icon: Icons.remove_rounded,
                      label: 'Col',
                      tooltip: 'Remove last column',
                      onPressed: _table.colCount > 1 ? _removeColumn : null,
                    ),
                    _buildActionButton(
                      icon: Icons.format_paint_rounded,
                      label: 'Header',
                      tooltip: 'Toggle Header Styling',
                      onPressed: _toggleHeaderRow,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 16, color: AppColors.danger),
                      tooltip: 'Delete Table',
                      onPressed: widget.onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Interactive Editable Table Grid
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Table(
                defaultColumnWidth: const FixedColumnWidth(160.0),
                border: TableBorder.all(
                  color: borderColor,
                  width: 1,
                  borderRadius: BorderRadius.circular(8),
                ),
                children: List.generate(_table.rowCount, (r) {
                  final isFirstRow = r == 0;
                  final isHeader = _table.cells[r][0].isHeader;
                  final rowBg = isHeader
                      ? headerBg
                      : (r.isEven ? rowAltBg : Colors.transparent);

                  return TableRow(
                    decoration: BoxDecoration(color: rowBg),
                    children: List.generate(_table.colCount, (c) {
                      final cell = _table.cells[r][c];
                      final ctrl = _controllers['$r-$c'] ??
                          TextEditingController(text: cell.text);

                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: TextFormField(
                          controller: ctrl,
                          style: GoogleFonts.poppins(
                            fontSize: isFirstRow && isHeader ? 13 : 12.5,
                            fontWeight: isFirstRow && isHeader
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isFirstRow && isHeader
                                ? AppColors.primary
                                : (isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight),
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            hintText: isFirstRow && isHeader
                                ? 'Header ${c + 1}'
                                : '...',
                            hintStyle: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white30 : Colors.black26,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 6),
                          ),
                          onChanged: (val) {
                            cell.text = val;
                            _notifyChange();
                          },
                        ),
                      );
                    }),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: onPressed != null
                ? AppColors.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: onPressed != null ? AppColors.primary : Colors.grey,
              ),
              const SizedBox(width: 3),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: onPressed != null ? AppColors.primary : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

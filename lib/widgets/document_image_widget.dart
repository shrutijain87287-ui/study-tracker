import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/note_model.dart';
import '../theme/app_theme.dart';

class DocumentImageWidget extends StatefulWidget {
  final NoteImageItem imageItem;
  final ValueChanged<NoteImageItem> onChanged;
  final VoidCallback onDelete;

  const DocumentImageWidget({
    super.key,
    required this.imageItem,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<DocumentImageWidget> createState() => _DocumentImageWidgetState();
}

class _DocumentImageWidgetState extends State<DocumentImageWidget> {
  late NoteImageItem _item;
  late TextEditingController _captionController;

  @override
  void initState() {
    super.initState();
    _item = widget.imageItem;
    _captionController = TextEditingController(text: _item.caption);
  }

  @override
  void didUpdateWidget(covariant DocumentImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageItem != widget.imageItem) {
      _item = widget.imageItem;
      if (_captionController.text != _item.caption) {
        _captionController.text = _item.caption;
      }
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  void _setAlignment(NoteImageAlignment align) {
    setState(() {
      _item = _item.copyWith(alignment: align);
    });
    widget.onChanged(_item);
  }

  void _setWidthScale(double scale) {
    setState(() {
      _item = _item.copyWith(widthScale: scale);
    });
    widget.onChanged(_item);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor =
        isDark ? const Color(0xFF3F3B66) : const Color(0xFFE2DCF5);

    Alignment containerAlign = Alignment.center;
    if (_item.alignment == NoteImageAlignment.left) {
      containerAlign = Alignment.centerLeft;
    } else if (_item.alignment == NoteImageAlignment.right) {
      containerAlign = Alignment.centerRight;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 14),
      alignment: containerAlign,
      child: FractionallySizedBox(
        widthFactor: _item.widthScale.clamp(0.2, 1.0),
        child: Container(
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
              // 1. Image Action Controls (Alignment, Sizing, Delete)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF262243)
                      : const Color(0xFFF7F5FD),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(15),
                    topRight: Radius.circular(15),
                  ),
                  border:
                      Border(bottom: BorderSide(color: borderColor, width: 1)),
                ),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Alignment buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSmallIconButton(
                          icon: Icons.format_align_left_rounded,
                          tooltip: 'Align Left',
                          isSelected:
                              _item.alignment == NoteImageAlignment.left,
                          onPressed: () =>
                              _setAlignment(NoteImageAlignment.left),
                        ),
                        _buildSmallIconButton(
                          icon: Icons.format_align_center_rounded,
                          tooltip: 'Align Center',
                          isSelected:
                              _item.alignment == NoteImageAlignment.center,
                          onPressed: () =>
                              _setAlignment(NoteImageAlignment.center),
                        ),
                        _buildSmallIconButton(
                          icon: Icons.format_align_right_rounded,
                          tooltip: 'Align Right',
                          isSelected:
                              _item.alignment == NoteImageAlignment.right,
                          onPressed: () =>
                              _setAlignment(NoteImageAlignment.right),
                        ),
                      ],
                    ),

                    // Width Scale Buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildScaleChip('33%', 0.33),
                        const SizedBox(width: 3),
                        _buildScaleChip('50%', 0.5),
                        const SizedBox(width: 3),
                        _buildScaleChip('75%', 0.75),
                        const SizedBox(width: 3),
                        _buildScaleChip('100%', 1.0),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 16, color: AppColors.danger),
                          tooltip: 'Delete Image',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: widget.onDelete,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 2. Image Content
              ClipRRect(
                child: _buildImageContent(isDark),
              ),

              // 3. Caption Input
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                child: TextField(
                  controller: _captionController,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: 'Add an optional image caption...',
                    hintStyle: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.white30 : Colors.black26,
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (val) {
                    _item = _item.copyWith(caption: val);
                    widget.onChanged(_item);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageContent(bool isDark) {
    if (_item.dataBase64.isNotEmpty) {
      try {
        final cleanBase64 = _item.dataBase64.contains(',')
            ? _item.dataBase64.split(',').last
            : _item.dataBase64;
        final bytes = base64Decode(cleanBase64);
        return Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _buildErrorPlaceholder(),
        );
      } catch (_) {
        return _buildErrorPlaceholder();
      }
    } else if (_item.url != null && _item.url!.isNotEmpty) {
      return Image.network(
        _item.url!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildErrorPlaceholder(),
      );
    }
    return _buildErrorPlaceholder();
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      height: 140,
      color: Colors.grey.withValues(alpha: 0.1),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_rounded, color: Colors.grey, size: 36),
            SizedBox(height: 6),
            Text('Image preview unavailable',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallIconButton({
    required IconData icon,
    required String tooltip,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 15,
            color: isSelected ? AppColors.primary : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildScaleChip(String label, double scale) {
    final isSelected = (_item.widthScale - scale).abs() < 0.05;
    return InkWell(
      onTap: () => _setWidthScale(scale),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade400,
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}

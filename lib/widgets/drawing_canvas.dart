import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/note_model.dart';
import '../theme/app_theme.dart';

/// Controller that manages vector strokes, tool states, undo/redo, and background
class DrawingCanvasController extends ChangeNotifier {
  List<DrawingStroke> _strokes = [];
  DrawingStroke? _currentStroke;

  final List<List<DrawingStroke>> _undoStack = [];
  final List<List<DrawingStroke>> _redoStack = [];

  DrawingTool _activeTool = DrawingTool.pen;
  DrawingShapeType _activeShape = DrawingShapeType.rectangle;
  Color _activeColor = AppColors.primary;
  double _activeStrokeWidth = 3.0;
  PageBackgroundStyle _backgroundStyle = PageBackgroundStyle.ruled;

  VoidCallback? onStrokesChanged;

  DrawingCanvasController({
    List<DrawingStroke>? initialStrokes,
    PageBackgroundStyle backgroundStyle = PageBackgroundStyle.ruled,
  }) {
    if (initialStrokes != null) {
      _strokes = List.from(initialStrokes);
    }
    _backgroundStyle = backgroundStyle;
  }

  List<DrawingStroke> get strokes => List.unmodifiable(_strokes);
  DrawingStroke? get currentStroke => _currentStroke;

  DrawingTool get activeTool => _activeTool;
  DrawingShapeType get activeShape => _activeShape;
  Color get activeColor => _activeColor;
  double get activeStrokeWidth => _activeStrokeWidth;
  PageBackgroundStyle get backgroundStyle => _backgroundStyle;

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  bool get isEmpty => _strokes.isEmpty;

  void setActiveTool(DrawingTool tool) {
    if (_activeTool != tool) {
      _activeTool = tool;
      if (tool == DrawingTool.highlighter) {
        _activeStrokeWidth = math.max(_activeStrokeWidth, 18.0);
      } else if (tool == DrawingTool.eraser) {
        _activeStrokeWidth = 24.0;
      } else if (tool == DrawingTool.pencil) {
        _activeStrokeWidth = 1.8;
      } else if (tool == DrawingTool.shape) {
        _activeStrokeWidth = 2.5;
      } else if (tool == DrawingTool.pen && _activeStrokeWidth > 10.0) {
        _activeStrokeWidth = 3.0;
      }
      notifyListeners();
    }
  }

  void setActiveShape(DrawingShapeType shape) {
    _activeShape = shape;
    _activeTool = DrawingTool.shape;
    _activeStrokeWidth = 2.5;
    notifyListeners();
  }

  void setActiveColor(Color color) {
    _activeColor = color;
    notifyListeners();
  }

  void setActiveStrokeWidth(double width) {
    _activeStrokeWidth = width;
    notifyListeners();
  }

  void setBackgroundStyle(PageBackgroundStyle style) {
    _backgroundStyle = style;
    notifyListeners();
  }

  void setStrokes(List<DrawingStroke> newStrokes) {
    _strokes = List.from(newStrokes);
    _undoStack.clear();
    _redoStack.clear();
    notifyListeners();
  }

  void startStroke(Offset point, [double pressure = 1.0]) {
    _recordUndo();

    if (_activeTool == DrawingTool.eraser) {
      _eraseAtPoint(point);
      return;
    }

    final double opacity = _activeTool == DrawingTool.highlighter
        ? 0.35
        : (_activeTool == DrawingTool.pencil ? 0.8 : 1.0);

    _currentStroke = DrawingStroke(
      id: 'stroke_${DateTime.now().microsecondsSinceEpoch}',
      points: [DrawingPoint(x: point.dx, y: point.dy, pressure: pressure)],
      colorValue: _activeColor.toARGB32(),
      strokeWidth: _activeStrokeWidth,
      tool: _activeTool,
      opacity: opacity,
      shapeType: _activeTool == DrawingTool.shape ? _activeShape : null,
    );
    notifyListeners();
  }

  void updateStroke(Offset point, [double pressure = 1.0]) {
    if (_activeTool == DrawingTool.eraser) {
      _eraseAtPoint(point);
      return;
    }

    if (_currentStroke == null) return;

    if (_activeTool == DrawingTool.shape) {
      // Shape only updates the end point
      final updatedPoints = [
        _currentStroke!.points.first,
        DrawingPoint(x: point.dx, y: point.dy, pressure: pressure),
      ];
      _currentStroke = _currentStroke!.copyWith(points: updatedPoints);
      notifyListeners();
      return;
    }

    // Filter points too close together to optimize vector points
    final lastPoint = _currentStroke!.points.last;
    final dist = math.sqrt(math.pow(point.dx - lastPoint.x, 2) +
        math.pow(point.dy - lastPoint.y, 2));

    if (dist >= 2.0) {
      final updatedPoints = List<DrawingPoint>.from(_currentStroke!.points)
        ..add(DrawingPoint(x: point.dx, y: point.dy, pressure: pressure));

      _currentStroke = _currentStroke!.copyWith(points: updatedPoints);
      notifyListeners();
    }
  }

  void endStroke() {
    if (_currentStroke != null) {
      _strokes.add(_currentStroke!);
      _currentStroke = null;
      _redoStack.clear();
      onStrokesChanged?.call();
      notifyListeners();
    }
  }

  void _eraseAtPoint(Offset point) {
    final double radius = _activeStrokeWidth / 2 + 8.0;
    bool erased = false;

    _strokes.removeWhere((stroke) {
      for (final p in stroke.points) {
        final dist = (p.offset - point).distance;
        if (dist <= radius) {
          erased = true;
          return true;
        }
      }
      return false;
    });

    if (erased) {
      _redoStack.clear();
      onStrokesChanged?.call();
      notifyListeners();
    }
  }

  void undo() {
    if (_undoStack.isNotEmpty) {
      _redoStack.add(List.from(_strokes));
      _strokes = _undoStack.removeLast();
      onStrokesChanged?.call();
      notifyListeners();
    }
  }

  void redo() {
    if (_redoStack.isNotEmpty) {
      _undoStack.add(List.from(_strokes));
      _strokes = _redoStack.removeLast();
      onStrokesChanged?.call();
      notifyListeners();
    }
  }

  void clear() {
    if (_strokes.isNotEmpty) {
      _recordUndo();
      _strokes.clear();
      _redoStack.clear();
      onStrokesChanged?.call();
      notifyListeners();
    }
  }

  void _recordUndo() {
    _undoStack.add(List.from(_strokes));
    if (_undoStack.length > 40) {
      _undoStack.removeAt(0);
    }
  }
}

/// CustomPainter for realistic ruled, grid, and dot notebook backgrounds
class NotebookPaperPainter extends CustomPainter {
  final PageBackgroundStyle style;
  final bool isDark;

  const NotebookPaperPainter({
    required this.style,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (style == PageBackgroundStyle.blank) return;

    final lineColor = isDark
        ? const Color(0xFF333060).withValues(alpha: 0.45)
        : AppColors.primary.withValues(alpha: 0.12);

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    if (style == PageBackgroundStyle.ruled) {
      // Horizontal ruled lines every 28.0 px
      const double lineSpacing = 28.0;
      const double startY = 40.0;

      for (double y = startY; y < size.height; y += lineSpacing) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
      }

      // Vertical margin line on left
      final marginPaint = Paint()
        ..color = isDark
            ? AppColors.pastelPinkText.withValues(alpha: 0.25)
            : AppColors.pastelPinkText.withValues(alpha: 0.35)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        const Offset(52.0, 0),
        Offset(52.0, size.height),
        marginPaint,
      );
    } else if (style == PageBackgroundStyle.grid) {
      // 24.0 x 24.0 grid lines
      const double gridSize = 24.0;
      for (double x = 0; x < size.width; x += gridSize) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
      }
      for (double y = 0; y < size.height; y += gridSize) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
      }
    } else if (style == PageBackgroundStyle.dots) {
      // Dot grid every 24.0 px
      const double dotSpacing = 24.0;
      final dotPaint = Paint()
        ..color = isDark
            ? Colors.white.withValues(alpha: 0.15)
            : AppColors.primary.withValues(alpha: 0.25)
        ..style = PaintingStyle.fill;

      for (double x = dotSpacing; x < size.width; x += dotSpacing) {
        for (double y = dotSpacing; y < size.height; y += dotSpacing) {
          canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant NotebookPaperPainter oldDelegate) {
    return oldDelegate.style != style || oldDelegate.isDark != isDark;
  }
}

/// CustomPainter for rendering vectorized DrawingStrokes with smooth bezier curves
class DrawingStrokesPainter extends CustomPainter {
  final List<DrawingStroke> strokes;
  final DrawingStroke? currentStroke;

  const DrawingStrokesPainter({
    required this.strokes,
    this.currentStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke);
    }
    if (currentStroke != null) {
      _drawStroke(canvas, currentStroke!);
    }
  }

  void _drawStroke(Canvas canvas, DrawingStroke stroke) {
    if (stroke.points.isEmpty) return;

    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = stroke.isHighlighter ? StrokeCap.square : StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (stroke.isHighlighter) {
      paint.blendMode = BlendMode.srcOver;
    }

    if (stroke.isShape && stroke.points.length >= 2) {
      final p0 = stroke.points.first.offset;
      final p1 = stroke.points.last.offset;
      final shape = stroke.shapeType ?? DrawingShapeType.rectangle;

      switch (shape) {
        case DrawingShapeType.rectangle:
          final rect = Rect.fromPoints(p0, p1);
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(8)),
            paint,
          );
          break;
        case DrawingShapeType.circle:
          final rect = Rect.fromPoints(p0, p1);
          canvas.drawOval(rect, paint);
          break;
        case DrawingShapeType.line:
          canvas.drawLine(p0, p1, paint);
          break;
        case DrawingShapeType.arrow:
          canvas.drawLine(p0, p1, paint);
          final angle = math.atan2(p1.dy - p0.dy, p1.dx - p0.dx);
          const arrowLength = 16.0;
          const arrowAngle = 28 * math.pi / 180;
          final path = Path()
            ..moveTo(p1.dx, p1.dy)
            ..lineTo(p1.dx - arrowLength * math.cos(angle - arrowAngle),
                p1.dy - arrowLength * math.sin(angle - arrowAngle))
            ..moveTo(p1.dx, p1.dy)
            ..lineTo(p1.dx - arrowLength * math.cos(angle + arrowAngle),
                p1.dy - arrowLength * math.sin(angle + arrowAngle));
          canvas.drawPath(path, paint);
          break;
        case DrawingShapeType.triangle:
          final path = Path()
            ..moveTo((p0.dx + p1.dx) / 2, p0.dy)
            ..lineTo(p1.dx, p1.dy)
            ..lineTo(p0.dx, p1.dy)
            ..close();
          canvas.drawPath(path, paint);
          break;
      }
      return;
    }

    if (stroke.points.length == 1) {
      final p = stroke.points.first.offset;
      canvas.drawCircle(
        p,
        stroke.strokeWidth / 2,
        Paint()
          ..color = stroke.color
          ..style = PaintingStyle.fill,
      );
      return;
    }

    final path = Path();
    path.moveTo(stroke.points[0].x, stroke.points[0].y);

    for (int i = 1; i < stroke.points.length - 1; i++) {
      final p0 = stroke.points[i].offset;
      final p1 = stroke.points[i + 1].offset;
      final midPoint = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      path.quadraticBezierTo(p0.dx, p0.dy, midPoint.dx, midPoint.dy);
    }

    final last = stroke.points.last.offset;
    path.lineTo(last.dx, last.dy);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant DrawingStrokesPainter oldDelegate) {
    return true;
  }
}

/// Interactive Drawing Canvas Widget with full gesture support and docked toolbar
class DrawingCanvasWidget extends StatefulWidget {
  final DrawingCanvasController controller;
  final VoidCallback? onClearRequest;

  const DrawingCanvasWidget({
    super.key,
    required this.controller,
    this.onClearRequest,
  });

  @override
  State<DrawingCanvasWidget> createState() => _DrawingCanvasWidgetState();
}

class _DrawingCanvasWidgetState extends State<DrawingCanvasWidget> {
  // Preset Palette
  static const List<Color> _palette = [
    Color(0xFF6C52EE), // Royal Purple (App Primary)
    Color(0xFF1E1D36), // Deep Slate Black
    Color(0xFF2D9CDB), // Sky / Pastel Blue
    Color(0xFFE0567A), // Rose Pink
    Color(0xFF10B981), // Emerald Green
    Color(0xFFF59E0B), // Amber Gold
    Color(0xFF0D9488), // Teal
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.cardDark : Colors.white;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        return Column(
          children: [
            // Top Toolbar for Drawing Tools & Colors
            _buildCanvasToolbar(cardBg, borderColor, isDark),

            // Canvas Body
            Expanded(
              child: ClipRect(
                child: Container(
                  width: double.infinity,
                  color: cardBg,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (d) =>
                        widget.controller.startStroke(d.localPosition),
                    onPanUpdate: (d) =>
                        widget.controller.updateStroke(d.localPosition),
                    onPanEnd: (d) => widget.controller.endStroke(),
                    child: CustomPaint(
                      painter: NotebookPaperPainter(
                        style: widget.controller.backgroundStyle,
                        isDark: isDark,
                      ),
                      foregroundPainter: DrawingStrokesPainter(
                        strokes: widget.controller.strokes,
                        currentStroke: widget.controller.currentStroke,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCanvasToolbar(Color cardBg, Color borderColor, bool isDark) {
    final ctrl = widget.controller;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          // 1. Tool Selectors (Pen, Pencil, Highlighter, Eraser)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildToolButton(
                tool: DrawingTool.pen,
                label: 'Pen',
                icon: Icons.edit_rounded,
                isSelected: ctrl.activeTool == DrawingTool.pen,
              ),
              const SizedBox(width: 4),
              _buildToolButton(
                tool: DrawingTool.pencil,
                label: 'Pencil',
                icon: Icons.mode_edit_outline_rounded,
                isSelected: ctrl.activeTool == DrawingTool.pencil,
              ),
              const SizedBox(width: 4),
              _buildToolButton(
                tool: DrawingTool.highlighter,
                label: 'Highlighter',
                icon: Icons.brush_rounded,
                isSelected: ctrl.activeTool == DrawingTool.highlighter,
              ),
              const SizedBox(width: 4),
              _buildToolButton(
                tool: DrawingTool.eraser,
                label: 'Eraser',
                icon: Icons.auto_fix_normal_rounded,
                isSelected: ctrl.activeTool == DrawingTool.eraser,
              ),
              const SizedBox(width: 4),
              PopupMenuButton<DrawingShapeType>(
                tooltip:
                    'Insert Shape (Rectangle, Circle, Line, Arrow, Triangle)',
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                onSelected: (shape) => ctrl.setActiveShape(shape),
                itemBuilder: (ctx) => DrawingShapeType.values.map((s) {
                  return PopupMenuItem(
                    value: s,
                    child: Row(
                      children: [
                        Icon(s.icon, size: 18, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Text(s.label),
                      ],
                    ),
                  );
                }).toList(),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: ctrl.activeTool == DrawingTool.shape
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: ctrl.activeTool == DrawingTool.shape
                          ? AppColors.primary
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        ctrl.activeTool == DrawingTool.shape
                            ? ctrl.activeShape.icon
                            : Icons.category_rounded,
                        size: 16,
                        color: ctrl.activeTool == DrawingTool.shape
                            ? AppColors.primary
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        ctrl.activeTool == DrawingTool.shape
                            ? ctrl.activeShape.label
                            : 'Shapes',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: ctrl.activeTool == DrawingTool.shape
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: ctrl.activeTool == DrawingTool.shape
                              ? AppColors.primary
                              : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 2. Color Palette (if not eraser)
          if (ctrl.activeTool != DrawingTool.eraser)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: _palette.map((c) {
                final isSelected = ctrl.activeColor.toARGB32() == c.toARGB32();
                return GestureDetector(
                  onTap: () => ctrl.setActiveColor(c),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: c.withValues(alpha: 0.5),
                                blurRadius: 6,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 14)
                        : null,
                  ),
                );
              }).toList(),
            ),

          // 3. Stroke Width / Thickness Presets
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStrokeWidthChip(
                label: 'Thin',
                width: ctrl.activeTool == DrawingTool.highlighter ? 12.0 : 1.5,
                isSelected: ctrl.activeStrokeWidth <= 2.0 ||
                    (ctrl.activeTool == DrawingTool.highlighter &&
                        ctrl.activeStrokeWidth <= 14.0),
              ),
              const SizedBox(width: 4),
              _buildStrokeWidthChip(
                label: 'Med',
                width: ctrl.activeTool == DrawingTool.highlighter ? 20.0 : 3.5,
                isSelected: (ctrl.activeStrokeWidth > 2.0 &&
                        ctrl.activeStrokeWidth <= 5.0) ||
                    (ctrl.activeTool == DrawingTool.highlighter &&
                        ctrl.activeStrokeWidth > 14.0 &&
                        ctrl.activeStrokeWidth <= 22.0),
              ),
              const SizedBox(width: 4),
              _buildStrokeWidthChip(
                label: 'Bold',
                width: ctrl.activeTool == DrawingTool.highlighter ? 32.0 : 6.5,
                isSelected: ctrl.activeStrokeWidth > 5.0 &&
                    ctrl.activeTool != DrawingTool.highlighter,
              ),
            ],
          ),

          // 4. Background Style Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF252340) : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<PageBackgroundStyle>(
                value: ctrl.backgroundStyle,
                isDense: true,
                icon: const Icon(Icons.arrow_drop_down_rounded, size: 20),
                items: PageBackgroundStyle.values.map((s) {
                  return DropdownMenuItem(
                    value: s,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(s.icon, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(s.label, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (s) {
                  if (s != null) ctrl.setBackgroundStyle(s);
                },
              ),
            ),
          ),

          // 5. Undo, Redo, Clear
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.undo_rounded, size: 20),
                tooltip: 'Undo stroke',
                onPressed: ctrl.canUndo ? ctrl.undo : null,
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: const Icon(Icons.redo_rounded, size: 20),
                tooltip: 'Redo stroke',
                onPressed: ctrl.canRedo ? ctrl.redo : null,
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.danger, size: 20),
                tooltip: 'Clear page strokes',
                onPressed: ctrl.isEmpty
                    ? null
                    : () {
                        _confirmClear(context);
                      },
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton({
    required DrawingTool tool,
    required String label,
    required IconData icon,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => widget.controller.setActiveTool(tool),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppColors.primary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStrokeWidthChip({
    required String label,
    required double width,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => widget.controller.setActiveStrokeWidth(width),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppColors.primary : null,
          ),
        ),
      ),
    );
  }

  void _confirmClear(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            SizedBox(width: 8),
            Text('Clear Drawings?'),
          ],
        ),
        content: const Text(
          'This will clear all handwritten strokes on this page. (You can undo this immediately with the Undo button).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.controller.clear();
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Clear Canvas'),
          ),
        ],
      ),
    );
  }
}

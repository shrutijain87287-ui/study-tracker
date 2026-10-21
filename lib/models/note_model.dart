import 'package:flutter/material.dart';

/// Available tools for the handwriting and drawing canvas
enum DrawingTool {
  pen,
  pencil,
  highlighter,
  eraser,
  shape,
}

enum DrawingShapeType {
  rectangle,
  circle,
  line,
  arrow,
  triangle,
}

extension DrawingShapeTypeExtension on DrawingShapeType {
  String get label {
    switch (this) {
      case DrawingShapeType.rectangle:
        return 'Rectangle';
      case DrawingShapeType.circle:
        return 'Circle / Oval';
      case DrawingShapeType.line:
        return 'Line';
      case DrawingShapeType.arrow:
        return 'Arrow';
      case DrawingShapeType.triangle:
        return 'Triangle';
    }
  }

  IconData get icon {
    switch (this) {
      case DrawingShapeType.rectangle:
        return Icons.crop_square_rounded;
      case DrawingShapeType.circle:
        return Icons.circle_outlined;
      case DrawingShapeType.line:
        return Icons.horizontal_rule_rounded;
      case DrawingShapeType.arrow:
        return Icons.arrow_right_alt_rounded;
      case DrawingShapeType.triangle:
        return Icons.change_history_rounded;
    }
  }
}

extension DrawingToolExtension on DrawingTool {
  String get label {
    switch (this) {
      case DrawingTool.pen:
        return 'Pen';
      case DrawingTool.pencil:
        return 'Pencil';
      case DrawingTool.highlighter:
        return 'Highlighter';
      case DrawingTool.eraser:
        return 'Eraser';
      case DrawingTool.shape:
        return 'Shape';
    }
  }

  IconData get icon {
    switch (this) {
      case DrawingTool.pen:
        return Icons.edit_rounded;
      case DrawingTool.pencil:
        return Icons.mode_edit_outline_rounded;
      case DrawingTool.highlighter:
        return Icons.brush_rounded;
      case DrawingTool.eraser:
        return Icons.auto_fix_normal_rounded;
      case DrawingTool.shape:
        return Icons.category_rounded;
    }
  }
}

/// Paper background styles for digital notes
enum PageBackgroundStyle {
  blank,
  ruled,
  grid,
  dots,
}

extension PageBackgroundStyleExtension on PageBackgroundStyle {
  String get label {
    switch (this) {
      case PageBackgroundStyle.blank:
        return 'Blank Paper';
      case PageBackgroundStyle.ruled:
        return 'Ruled / Lined';
      case PageBackgroundStyle.grid:
        return 'Grid / Math';
      case PageBackgroundStyle.dots:
        return 'Dot Grid';
    }
  }

  IconData get icon {
    switch (this) {
      case PageBackgroundStyle.blank:
        return Icons.crop_portrait_rounded;
      case PageBackgroundStyle.ruled:
        return Icons.format_align_justify_rounded;
      case PageBackgroundStyle.grid:
        return Icons.grid_on_rounded;
      case PageBackgroundStyle.dots:
        return Icons.scatter_plot_rounded;
    }
  }
}

/// A single coordinate point in a drawing stroke
class DrawingPoint {
  final double x;
  final double y;
  final double pressure;

  const DrawingPoint({
    required this.x,
    required this.y,
    this.pressure = 1.0,
  });

  Offset get offset => Offset(x, y);

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'pressure': pressure,
      };

  factory DrawingPoint.fromJson(Map<String, dynamic> json) {
    return DrawingPoint(
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      pressure: (json['pressure'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

/// A continuous stroke drawn with a pen, pencil, highlighter, or shape tool
class DrawingStroke {
  final String id;
  final List<DrawingPoint> points;
  final int colorValue;
  final double strokeWidth;
  final DrawingTool tool;
  final double opacity;
  final DrawingShapeType? shapeType;

  const DrawingStroke({
    required this.id,
    required this.points,
    required this.colorValue,
    required this.strokeWidth,
    required this.tool,
    this.opacity = 1.0,
    this.shapeType,
  });

  Color get color => Color(colorValue).withValues(alpha: opacity);

  bool get isHighlighter => tool == DrawingTool.highlighter;
  bool get isEraser => tool == DrawingTool.eraser;
  bool get isShape => tool == DrawingTool.shape && shapeType != null;

  DrawingStroke copyWith({
    String? id,
    List<DrawingPoint>? points,
    int? colorValue,
    double? strokeWidth,
    DrawingTool? tool,
    double? opacity,
    DrawingShapeType? shapeType,
  }) {
    return DrawingStroke(
      id: id ?? this.id,
      points: points ?? this.points,
      colorValue: colorValue ?? this.colorValue,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      tool: tool ?? this.tool,
      opacity: opacity ?? this.opacity,
      shapeType: shapeType ?? this.shapeType,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'points': points.map((p) => p.toJson()).toList(),
        'colorValue': colorValue,
        'strokeWidth': strokeWidth,
        'tool': tool.name,
        'opacity': opacity,
        if (shapeType != null) 'shapeType': shapeType!.name,
      };

  factory DrawingStroke.fromJson(Map<String, dynamic> json) {
    DrawingTool parseTool = DrawingTool.pen;
    final tStr = json['tool'] as String?;
    if (tStr != null) {
      parseTool = DrawingTool.values.firstWhere(
        (t) => t.name == tStr,
        orElse: () => DrawingTool.pen,
      );
    }

    DrawingShapeType? parseShape;
    final sStr = json['shapeType'] as String?;
    if (sStr != null) {
      parseShape = DrawingShapeType.values.firstWhere(
        (s) => s.name == sStr,
        orElse: () => DrawingShapeType.rectangle,
      );
    }

    final rawPoints = json['points'] as List? ?? [];
    final points = rawPoints
        .map((p) => DrawingPoint.fromJson(Map<String, dynamic>.from(p as Map)))
        .toList();

    return DrawingStroke(
      id: json['id'] as String? ??
          'stroke_${DateTime.now().microsecondsSinceEpoch}',
      points: points,
      colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFF6C52EE,
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 2.5,
      tool: parseTool,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      shapeType: parseShape,
    );
  }
}

/// Document Page Sizes for Word-like layout
enum DocumentPageSize {
  a4,
  letter,
  fluid,
}

extension DocumentPageSizeExtension on DocumentPageSize {
  String get label {
    switch (this) {
      case DocumentPageSize.a4:
        return 'A4 (210 × 297 mm)';
      case DocumentPageSize.letter:
        return 'Letter (8.5 × 11 in)';
      case DocumentPageSize.fluid:
        return 'Fluid / Responsive';
    }
  }

  double? get targetWidth {
    switch (this) {
      case DocumentPageSize.a4:
        return 794.0;
      case DocumentPageSize.letter:
        return 816.0;
      case DocumentPageSize.fluid:
        return null;
    }
  }
}

/// Document Page Orientation
enum DocumentOrientation {
  portrait,
  landscape,
}

/// Document Margins
enum DocumentMargin {
  normal, // 24px
  narrow, // 12px
  wide, // 36px
}

extension DocumentMarginExtension on DocumentMargin {
  String get label {
    switch (this) {
      case DocumentMargin.normal:
        return 'Normal (24 px)';
      case DocumentMargin.narrow:
        return 'Narrow (12 px)';
      case DocumentMargin.wide:
        return 'Wide (36 px)';
    }
  }

  double get padding {
    switch (this) {
      case DocumentMargin.normal:
        return 24.0;
      case DocumentMargin.narrow:
        return 12.0;
      case DocumentMargin.wide:
        return 36.0;
    }
  }
}

/// Page layout settings for Microsoft Word-style formatting
class NotePageLayout {
  final DocumentPageSize pageSize;
  final DocumentOrientation orientation;
  final DocumentMargin margin;
  final String fontFamily;
  final double fontSize;
  final double lineSpacing;

  const NotePageLayout({
    this.pageSize = DocumentPageSize.a4,
    this.orientation = DocumentOrientation.portrait,
    this.margin = DocumentMargin.normal,
    this.fontFamily = 'Poppins',
    this.fontSize = 15.0,
    this.lineSpacing = 1.6,
  });

  NotePageLayout copyWith({
    DocumentPageSize? pageSize,
    DocumentOrientation? orientation,
    DocumentMargin? margin,
    String? fontFamily,
    double? fontSize,
    double? lineSpacing,
  }) {
    return NotePageLayout(
      pageSize: pageSize ?? this.pageSize,
      orientation: orientation ?? this.orientation,
      margin: margin ?? this.margin,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      lineSpacing: lineSpacing ?? this.lineSpacing,
    );
  }

  Map<String, dynamic> toJson() => {
        'pageSize': pageSize.name,
        'orientation': orientation.name,
        'margin': margin.name,
        'fontFamily': fontFamily,
        'fontSize': fontSize,
        'lineSpacing': lineSpacing,
      };

  factory NotePageLayout.fromJson(Map<String, dynamic> json) {
    DocumentPageSize ps = DocumentPageSize.a4;
    final psStr = json['pageSize'] as String?;
    if (psStr != null) {
      ps = DocumentPageSize.values.firstWhere(
        (e) => e.name == psStr,
        orElse: () => DocumentPageSize.a4,
      );
    }

    DocumentOrientation ori = DocumentOrientation.portrait;
    final oriStr = json['orientation'] as String?;
    if (oriStr != null) {
      ori = DocumentOrientation.values.firstWhere(
        (e) => e.name == oriStr,
        orElse: () => DocumentOrientation.portrait,
      );
    }

    DocumentMargin m = DocumentMargin.normal;
    final mStr = json['margin'] as String?;
    if (mStr != null) {
      m = DocumentMargin.values.firstWhere(
        (e) => e.name == mStr,
        orElse: () => DocumentMargin.normal,
      );
    }

    return NotePageLayout(
      pageSize: ps,
      orientation: ori,
      margin: m,
      fontFamily: json['fontFamily'] as String? ?? 'Poppins',
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 15.0,
      lineSpacing: (json['lineSpacing'] as num?)?.toDouble() ?? 1.6,
    );
  }
}

/// A single cell in an editable document table
class NoteTableCell {
  String text;
  bool isHeader;
  TextAlign align;
  int? backgroundColorValue;

  NoteTableCell({
    this.text = '',
    this.isHeader = false,
    this.align = TextAlign.left,
    this.backgroundColorValue,
  });

  NoteTableCell copyWith({
    String? text,
    bool? isHeader,
    TextAlign? align,
    int? backgroundColorValue,
  }) {
    return NoteTableCell(
      text: text ?? this.text,
      isHeader: isHeader ?? this.isHeader,
      align: align ?? this.align,
      backgroundColorValue: backgroundColorValue ?? this.backgroundColorValue,
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'isHeader': isHeader,
        'align': align.name,
        'backgroundColorValue': backgroundColorValue,
      };

  factory NoteTableCell.fromJson(Map<String, dynamic> json) {
    TextAlign parsedAlign = TextAlign.left;
    final aStr = json['align'] as String?;
    if (aStr != null) {
      parsedAlign = TextAlign.values.firstWhere(
        (a) => a.name == aStr,
        orElse: () => TextAlign.left,
      );
    }
    return NoteTableCell(
      text: json['text'] as String? ?? '',
      isHeader: json['isHeader'] as bool? ?? false,
      align: parsedAlign,
      backgroundColorValue: json['backgroundColorValue'] as int?,
    );
  }
}

/// An authentic editable document table
class NoteTable {
  final String id;
  String? caption;
  int rowCount;
  int colCount;
  List<List<NoteTableCell>> cells;

  NoteTable({
    required this.id,
    this.caption,
    required this.rowCount,
    required this.colCount,
    required this.cells,
  });

  factory NoteTable.create({
    required String id,
    int rows = 3,
    int cols = 3,
    String? caption,
  }) {
    final List<List<NoteTableCell>> grid = [];
    for (int r = 0; r < rows; r++) {
      final List<NoteTableCell> rowCells = [];
      for (int c = 0; c < cols; c++) {
        rowCells.add(NoteTableCell(
          text: r == 0 ? 'Header ${c + 1}' : 'Cell ${r + 1},${c + 1}',
          isHeader: r == 0,
        ));
      }
      grid.add(rowCells);
    }
    return NoteTable(
      id: id,
      caption: caption,
      rowCount: rows,
      colCount: cols,
      cells: grid,
    );
  }

  void addRow([int? atIndex]) {
    final index = atIndex ?? rowCount;
    final List<NoteTableCell> newRow = List.generate(
      colCount,
      (c) => NoteTableCell(text: 'Row ${rowCount + 1}, Col ${c + 1}'),
    );
    cells.insert(index, newRow);
    rowCount = cells.length;
  }

  void removeRow(int index) {
    if (rowCount > 1 && index >= 0 && index < rowCount) {
      cells.removeAt(index);
      rowCount = cells.length;
    }
  }

  void addColumn([int? atIndex]) {
    final index = atIndex ?? colCount;
    for (int r = 0; r < rowCount; r++) {
      cells[r].insert(
        index,
        NoteTableCell(
          text: r == 0 ? 'Header ${colCount + 1}' : 'Data',
          isHeader: r == 0,
        ),
      );
    }
    colCount = cells.first.length;
  }

  void removeColumn(int index) {
    if (colCount > 1 && index >= 0 && index < colCount) {
      for (int r = 0; r < rowCount; r++) {
        cells[r].removeAt(index);
      }
      colCount = cells.first.length;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'caption': caption,
        'rowCount': rowCount,
        'colCount': colCount,
        'cells': cells
            .map((row) => row.map((cell) => cell.toJson()).toList())
            .toList(),
      };

  factory NoteTable.fromJson(Map<String, dynamic> json) {
    final rawCells = json['cells'] as List? ?? [];
    final List<List<NoteTableCell>> grid = [];

    for (final r in rawCells) {
      final rowList = (r as List? ?? [])
          .map((c) =>
              NoteTableCell.fromJson(Map<String, dynamic>.from(c as Map)))
          .toList();
      grid.add(rowList);
    }

    final int rCount = (json['rowCount'] as num?)?.toInt() ?? grid.length;
    final int cCount = (json['colCount'] as num?)?.toInt() ??
        (grid.isNotEmpty ? grid.first.length : 0);

    return NoteTable(
      id: json['id'] as String? ??
          'tbl_${DateTime.now().microsecondsSinceEpoch}',
      caption: json['caption'] as String?,
      rowCount: rCount,
      colCount: cCount,
      cells: grid,
    );
  }
}

/// Image alignment within document
enum NoteImageAlignment { left, center, right }

/// An inserted picture or media item
class NoteImageItem {
  final String id;
  String dataBase64;
  String? url;
  String caption;
  String altText;
  NoteImageAlignment alignment;
  double widthScale; // 0.33, 0.5, 0.75, 1.0

  NoteImageItem({
    required this.id,
    this.dataBase64 = '',
    this.url,
    this.caption = '',
    this.altText = '',
    this.alignment = NoteImageAlignment.center,
    this.widthScale = 0.8,
  });

  NoteImageItem copyWith({
    String? id,
    String? dataBase64,
    String? url,
    String? caption,
    String? altText,
    NoteImageAlignment? alignment,
    double? widthScale,
  }) {
    return NoteImageItem(
      id: id ?? this.id,
      dataBase64: dataBase64 ?? this.dataBase64,
      url: url ?? this.url,
      caption: caption ?? this.caption,
      altText: altText ?? this.altText,
      alignment: alignment ?? this.alignment,
      widthScale: widthScale ?? this.widthScale,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'dataBase64': dataBase64,
        'url': url,
        'caption': caption,
        'altText': altText,
        'alignment': alignment.name,
        'widthScale': widthScale,
      };

  factory NoteImageItem.fromJson(Map<String, dynamic> json) {
    NoteImageAlignment align = NoteImageAlignment.center;
    final aStr = json['alignment'] as String?;
    if (aStr != null) {
      align = NoteImageAlignment.values.firstWhere(
        (a) => a.name == aStr,
        orElse: () => NoteImageAlignment.center,
      );
    }

    return NoteImageItem(
      id: json['id'] as String? ??
          'img_${DateTime.now().microsecondsSinceEpoch}',
      dataBase64: json['dataBase64'] as String? ?? '',
      url: json['url'] as String?,
      caption: json['caption'] as String? ?? '',
      altText: json['altText'] as String? ?? '',
      alignment: align,
      widthScale: (json['widthScale'] as num?)?.toDouble() ?? 0.8,
    );
  }
}

/// A single page inside a multi-page Notebook
class NotePage {
  final String id;
  int pageNumber;
  String title;
  String content;
  List<DrawingStroke> drawingStrokes;
  PageBackgroundStyle backgroundStyle;
  NotePageLayout layout;
  List<NoteTable> tables;
  List<NoteImageItem> images;
  DateTime createdAt;
  DateTime updatedAt;

  NotePage({
    required this.id,
    required this.pageNumber,
    this.title = '',
    this.content = '',
    List<DrawingStroke>? drawingStrokes,
    this.backgroundStyle = PageBackgroundStyle.ruled,
    this.layout = const NotePageLayout(),
    List<NoteTable>? tables,
    List<NoteImageItem>? images,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : drawingStrokes = drawingStrokes ?? [],
        tables = tables ?? [],
        images = images ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isEmpty =>
      content.trim().isEmpty &&
      drawingStrokes.isEmpty &&
      tables.isEmpty &&
      images.isEmpty;

  int get wordCount {
    if (content.trim().isEmpty) return 0;
    return content.trim().split(RegExp(r'\s+')).length;
  }

  NotePage copyWith({
    String? id,
    int? pageNumber,
    String? title,
    String? content,
    List<DrawingStroke>? drawingStrokes,
    PageBackgroundStyle? backgroundStyle,
    NotePageLayout? layout,
    List<NoteTable>? tables,
    List<NoteImageItem>? images,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotePage(
      id: id ?? this.id,
      pageNumber: pageNumber ?? this.pageNumber,
      title: title ?? this.title,
      content: content ?? this.content,
      drawingStrokes: drawingStrokes ?? List.from(this.drawingStrokes),
      backgroundStyle: backgroundStyle ?? this.backgroundStyle,
      layout: layout ?? this.layout,
      tables: tables ?? List.from(this.tables),
      images: images ?? List.from(this.images),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'pageNumber': pageNumber,
        'title': title,
        'content': content,
        'drawingStrokes': drawingStrokes.map((s) => s.toJson()).toList(),
        'backgroundStyle': backgroundStyle.name,
        'layout': layout.toJson(),
        'tables': tables.map((t) => t.toJson()).toList(),
        'images': images.map((img) => img.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory NotePage.fromJson(Map<String, dynamic> json) {
    PageBackgroundStyle bg = PageBackgroundStyle.ruled;
    final bgStr = json['backgroundStyle'] as String?;
    if (bgStr != null) {
      bg = PageBackgroundStyle.values.firstWhere(
        (e) => e.name == bgStr,
        orElse: () => PageBackgroundStyle.ruled,
      );
    }

    final rawStrokes = json['drawingStrokes'] as List? ?? [];
    final strokes = rawStrokes
        .map((s) => DrawingStroke.fromJson(Map<String, dynamic>.from(s as Map)))
        .toList();

    NotePageLayout pageLayout = const NotePageLayout();
    if (json['layout'] != null) {
      pageLayout = NotePageLayout.fromJson(
          Map<String, dynamic>.from(json['layout'] as Map));
    }

    final rawTables = json['tables'] as List? ?? [];
    final tables = rawTables
        .map((t) => NoteTable.fromJson(Map<String, dynamic>.from(t as Map)))
        .toList();

    final rawImages = json['images'] as List? ?? [];
    final images = rawImages
        .map((img) =>
            NoteImageItem.fromJson(Map<String, dynamic>.from(img as Map)))
        .toList();

    return NotePage(
      id: json['id'] as String? ??
          'page_${DateTime.now().microsecondsSinceEpoch}',
      pageNumber: (json['pageNumber'] as num?)?.toInt() ?? 1,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      drawingStrokes: strokes,
      backgroundStyle: bg,
      layout: pageLayout,
      tables: tables,
      images: images,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// Represents a Digital Notebook belonging to a student, organized by study category,
/// subject, chapter, or linked to a saved YouTube class.
class Notebook {
  final String id;
  String title;
  String? description;
  String category;
  String? subjectId;
  String? subjectName;
  String? chapterId;
  String? chapterTitle;
  String? linkedVideoId;
  String? linkedVideoTitle;
  int coverColorValue;
  int? iconCodePoint;
  List<String> tags;
  bool isFavorite;
  List<NotePage> pages;
  DateTime createdAt;
  DateTime updatedAt;

  Notebook({
    required this.id,
    required this.title,
    this.description,
    this.category = 'General',
    this.subjectId,
    this.subjectName,
    this.chapterId,
    this.chapterTitle,
    this.linkedVideoId,
    this.linkedVideoTitle,
    this.coverColorValue = 0xFF6C52EE, // AppColors.primary
    this.iconCodePoint,
    List<String>? tags,
    this.isFavorite = false,
    List<NotePage>? pages,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : tags = tags ?? [],
        pages = pages ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Color get coverColor => Color(coverColorValue);

  int get pageCount => pages.length;
  int get totalPages => pages.length;

  int get totalWordCount => pages.fold(0, (sum, p) => sum + p.wordCount);

  int get totalStrokeCount =>
      pages.fold(0, (sum, p) => sum + p.drawingStrokes.length);

  bool get hasDrawings => pages.any((p) => p.drawingStrokes.isNotEmpty);

  String get lastEditedRelative {
    final diff = DateTime.now().difference(updatedAt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${updatedAt.day}/${updatedAt.month}/${updatedAt.year}';
  }

  bool get isLinkedToClass =>
      linkedVideoId != null && linkedVideoId!.trim().isNotEmpty;

  bool get isLinkedToSubject =>
      subjectId != null && subjectId!.trim().isNotEmpty;

  String get summaryPreview {
    if (description != null && description!.trim().isNotEmpty) {
      return description!.trim();
    }
    for (final page in pages) {
      if (page.content.trim().isNotEmpty) {
        final clean = page.content.replaceAll(RegExp(r'[#*_`•\-]'), '').trim();
        if (clean.isNotEmpty) {
          return clean.length > 120 ? '${clean.substring(0, 117)}...' : clean;
        }
      }
    }
    return 'No notes written yet.';
  }

  Notebook copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? subjectId,
    String? subjectName,
    String? chapterId,
    String? chapterTitle,
    String? linkedVideoId,
    String? linkedVideoTitle,
    int? coverColorValue,
    int? iconCodePoint,
    List<String>? tags,
    bool? isFavorite,
    List<NotePage>? pages,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Notebook(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      subjectId: subjectId ?? this.subjectId,
      subjectName: subjectName ?? this.subjectName,
      chapterId: chapterId ?? this.chapterId,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      linkedVideoId: linkedVideoId ?? this.linkedVideoId,
      linkedVideoTitle: linkedVideoTitle ?? this.linkedVideoTitle,
      coverColorValue: coverColorValue ?? this.coverColorValue,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      tags: tags ?? List.from(this.tags),
      isFavorite: isFavorite ?? this.isFavorite,
      pages: pages ?? List.from(this.pages),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category,
        'subjectId': subjectId,
        'subjectName': subjectName,
        'chapterId': chapterId,
        'chapterTitle': chapterTitle,
        'linkedVideoId': linkedVideoId,
        'linkedVideoTitle': linkedVideoTitle,
        'coverColorValue': coverColorValue,
        'iconCodePoint': iconCodePoint,
        'tags': tags,
        'isFavorite': isFavorite,
        'pages': pages.map((p) => p.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Notebook.fromJson(Map<String, dynamic> json) {
    final rawPages = json['pages'] as List? ?? [];
    final pages = rawPages
        .map((p) => NotePage.fromJson(Map<String, dynamic>.from(p as Map)))
        .toList();

    final rawTags = json['tags'] as List? ?? [];
    final tags = rawTags.map((t) => t.toString()).toList();

    return Notebook(
      id: json['id'] as String? ??
          'nb_${DateTime.now().microsecondsSinceEpoch}',
      title: json['title'] as String? ?? 'Untitled Notebook',
      description: json['description'] as String?,
      category: json['category'] as String? ?? 'General',
      subjectId: json['subjectId'] as String?,
      subjectName: json['subjectName'] as String?,
      chapterId: json['chapterId'] as String?,
      chapterTitle: json['chapterTitle'] as String?,
      linkedVideoId: json['linkedVideoId'] as String?,
      linkedVideoTitle: json['linkedVideoTitle'] as String?,
      coverColorValue: (json['coverColorValue'] as num?)?.toInt() ?? 0xFF6C52EE,
      iconCodePoint: (json['iconCodePoint'] as num?)?.toInt(),
      tags: tags,
      isFavorite: json['isFavorite'] as bool? ?? false,
      pages: pages,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

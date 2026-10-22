import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ca_inter_tracker/models/note_model.dart';
import 'package:ca_inter_tracker/models/study_plan.dart';
import 'package:ca_inter_tracker/services/notes_pdf_service.dart';
import 'package:ca_inter_tracker/services/storage_service.dart';
import 'package:ca_inter_tracker/widgets/drawing_canvas.dart';
import 'package:ca_inter_tracker/widgets/rich_notes_editor.dart';
import 'package:ca_inter_tracker/screens/notes_library_screen.dart';
import 'package:ca_inter_tracker/screens/notebook_editor_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Digital Notes Models and Serialization', () {
    test('DrawingPoint JSON serialization', () {
      const pt = DrawingPoint(x: 120.5, y: 340.2, pressure: 0.85);
      final json = pt.toJson();
      expect(json['x'], 120.5);
      expect(json['y'], 340.2);
      expect(json['pressure'], 0.85);

      final reconstructed = DrawingPoint.fromJson(json);
      expect(reconstructed.x, 120.5);
      expect(reconstructed.y, 340.2);
      expect(reconstructed.offset, const Offset(120.5, 340.2));
    });

    test('DrawingStroke JSON serialization and tool types', () {
      const stroke = DrawingStroke(
        id: 's_001',
        points: [
          DrawingPoint(x: 10, y: 20),
          DrawingPoint(x: 15, y: 25),
        ],
        colorValue: 0xFF6C52EE,
        strokeWidth: 4.5,
        tool: DrawingTool.highlighter,
        opacity: 0.35,
      );

      final json = stroke.toJson();
      expect(json['id'], 's_001');
      expect(json['tool'], 'highlighter');
      expect(json['opacity'], 0.35);

      final restored = DrawingStroke.fromJson(json);
      expect(restored.id, 's_001');
      expect(restored.tool, DrawingTool.highlighter);
      expect(restored.isHighlighter, true);
      expect(restored.points.length, 2);
    });

    test('NotePage word count, empty check, and copyWith', () {
      final page = NotePage(
        id: 'p_01',
        pageNumber: 1,
        title: 'Overview',
        content: '# Heading\nThis is a sample sentence with eight words.',
        backgroundStyle: PageBackgroundStyle.grid,
      );

      expect(page.isEmpty, false);
      expect(page.wordCount, 10);
      expect(page.backgroundStyle, PageBackgroundStyle.grid);

      final emptyPage = NotePage(id: 'p_02', pageNumber: 2);
      expect(emptyPage.isEmpty, true);
      expect(emptyPage.wordCount, 0);

      final updated = page.copyWith(title: 'New Title', pageNumber: 3);
      expect(updated.title, 'New Title');
      expect(updated.pageNumber, 3);
      expect(updated.content, page.content);
    });

    test('Notebook stats, getters, and JSON roundtrip', () {
      final nb = Notebook(
        id: 'nb_test_1',
        title: 'Accounting Standards AS 10',
        description: 'Comprehensive property, plant and equipment notes',
        category: 'Professional Exam',
        subjectId: 'sub_acc',
        subjectName: 'Advanced Accounting',
        chapterId: 'chap_10',
        chapterTitle: 'AS 10: PPE',
        linkedVideoId: 'yt_as10_123',
        linkedVideoTitle: 'AS 10 Masterclass',
        coverColorValue: 0xFF2D9CDB,
        tags: ['as10', 'accounting', 'exam'],
        isFavorite: true,
        pages: [
          NotePage(
            id: 'p_1',
            pageNumber: 1,
            title: 'Scope',
            content: 'AS 10 applies to property, plant and equipment.',
            drawingStrokes: const [
              DrawingStroke(
                id: 'str_1',
                points: [DrawingPoint(x: 5, y: 10)],
                colorValue: 0xFF6C52EE,
                strokeWidth: 2,
                tool: DrawingTool.pen,
              ),
            ],
          ),
          NotePage(
            id: 'p_2',
            pageNumber: 2,
            title: 'Measurement',
            content: 'Cost model vs Revaluation model.',
            drawingStrokes: const [],
          ),
        ],
      );

      expect(nb.totalPages, 2);
      expect(nb.pageCount, 2);
      expect(nb.totalWordCount, 13);
      expect(nb.hasDrawings, true);
      expect(nb.totalStrokeCount, 1);
      expect(nb.isLinkedToClass, true);
      expect(nb.isLinkedToSubject, true);

      final json = nb.toJson();
      final restored = Notebook.fromJson(json);

      expect(restored.id, nb.id);
      expect(restored.title, nb.title);
      expect(restored.category, nb.category);
      expect(restored.linkedVideoId, 'yt_as10_123');
      expect(restored.isFavorite, true);
      expect(restored.pages.length, 2);
      expect(restored.pages.first.drawingStrokes.length, 1);
    });
  });

  group('StorageService Digital Notes Operations', () {
    test(
        'loadNotebooks returns empty list when storage is empty without seeding sample notes',
        () async {
      final notebooks = await StorageService.loadNotebooks();
      expect(notebooks.isEmpty, true);
    });

    test(
        'loadNotebooks safely purges legacy starter notebook without touching user notebooks',
        () async {
      final legacy = Notebook(
        id: 'nb_welcome_starter',
        title: 'Welcome to Digital Notes 📓',
        category: 'General',
        pages: [NotePage(id: 'p0', pageNumber: 1, content: 'Starter')],
      );
      final userNb = Notebook(
        id: 'nb_user_real',
        title: 'My Real Exam Notes',
        category: 'Taxation',
        pages: [NotePage(id: 'p1', pageNumber: 1, content: 'Section 44AD')],
      );
      await StorageService.saveNotebooks([legacy, userNb]);
      final loaded = await StorageService.loadNotebooks();
      expect(loaded.length, 1);
      expect(loaded.first.id, 'nb_user_real');
      expect(loaded.first.title, 'My Real Exam Notes');
    });

    test('saveNotebook, getNotebookById, and deleteNotebook CRUD flow',
        () async {
      final nb = Notebook(
        id: 'nb_audit_01',
        title: 'Audit Standards',
        category: 'Professional Exam',
        pages: [NotePage(id: 'p1', pageNumber: 1, content: 'SA 200 Overview')],
      );

      await StorageService.saveNotebook(nb);

      final retrieved = await StorageService.getNotebookById('nb_audit_01');
      expect(retrieved, isNotNull);
      expect(retrieved!.title, 'Audit Standards');

      // Update notebook
      retrieved.title = 'Audit Standards (SA 200-700)';
      await StorageService.saveNotebook(retrieved);

      final updated = await StorageService.getNotebookById('nb_audit_01');
      expect(updated!.title, 'Audit Standards (SA 200-700)');

      // Delete notebook
      await StorageService.deleteNotebook('nb_audit_01');
      final deleted = await StorageService.getNotebookById('nb_audit_01');
      expect(deleted, isNull);
    });

    test('getNotebooksForClass filters by videoId', () async {
      final nb1 = Notebook(
        id: 'nb_vid_1',
        title: 'Video 1 Notes',
        linkedVideoId: 'video_xyz',
      );
      final nb2 = Notebook(
        id: 'nb_vid_2',
        title: 'Video 2 Notes',
        linkedVideoId: 'video_abc',
      );

      await StorageService.saveNotebook(nb1);
      await StorageService.saveNotebook(nb2);

      final forXyz = await StorageService.getNotebooksForClass('video_xyz');
      expect(forXyz.length, 1);
      expect(forXyz.first.id, 'nb_vid_1');

      final forNone =
          await StorageService.getNotebooksForClass('video_nonexistent');
      expect(forNone.isEmpty, true);
    });
  });

  group('RichNotesTextEditingController Markdown Rendering', () {
    testWidgets('Controller formats headings and bullet items in TextSpan',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final controller = RichNotesTextEditingController(
                  text:
                      '# H1 Heading\n## H2 Heading\n• Bullet Point\nPlain text',
                );

                final span = controller.buildTextSpan(
                  context: context,
                  withComposing: false,
                );

                expect(span.children, isNotNull);
                expect(span.children!.length, 4);

                return const SizedBox();
              },
            ),
          ),
        ),
      );
    });
  });

  group('DrawingCanvasController Vector Operations', () {
    test('Tool switching, stroke addition, undo, redo, and clear', () {
      final controller = DrawingCanvasController(
        backgroundStyle: PageBackgroundStyle.ruled,
      );

      expect(controller.activeTool, DrawingTool.pen);
      expect(controller.backgroundStyle, PageBackgroundStyle.ruled);
      expect(controller.canUndo, false);

      controller.setActiveTool(DrawingTool.highlighter);
      expect(controller.activeTool, DrawingTool.highlighter);
      expect(controller.activeStrokeWidth >= 18.0, true);

      // Start stroke
      controller.startStroke(const Offset(10, 10));
      controller.updateStroke(const Offset(20, 20));
      controller.endStroke();

      expect(controller.strokes.length, 1);
      expect(controller.canUndo, true);
      expect(controller.canRedo, false);

      // Undo
      controller.undo();
      expect(controller.strokes.isEmpty, true);
      expect(controller.canRedo, true);

      // Redo
      controller.redo();
      expect(controller.strokes.length, 1);

      // Clear
      controller.clear();
      expect(controller.strokes.isEmpty, true);
    });

    test('Background style updates correctly', () {
      final controller = DrawingCanvasController();
      controller.setBackgroundStyle(PageBackgroundStyle.grid);
      expect(controller.backgroundStyle, PageBackgroundStyle.grid);
    });
  });

  group('NotesPdfService PDF Export Generation', () {
    test('Generates valid non-empty PDF byte stream with text and strokes',
        () async {
      final notebook = Notebook(
        id: 'pdf_test_nb',
        title: 'Taxation Essentials',
        description: 'Direct & Indirect Tax Revision',
        category: 'Professional Exam',
        subjectName: 'Taxation',
        pages: [
          NotePage(
            id: 'p1',
            pageNumber: 1,
            title: 'Section 1: Basics',
            content:
                '# Basis of Charge\n## Rates of Tax\n• Surcharge\n• Cess\n> Important case law',
            drawingStrokes: const [
              DrawingStroke(
                id: 'str1',
                points: [
                  DrawingPoint(x: 20, y: 30),
                  DrawingPoint(x: 40, y: 50),
                ],
                colorValue: 0xFF6C52EE,
                strokeWidth: 3,
                tool: DrawingTool.pen,
              ),
            ],
          ),
        ],
      );

      final bytes = await NotesPdfService.generateNotebookPdfBytes(notebook);
      expect(bytes.isNotEmpty, true);
      // PDF documents start with %PDF magic header
      final header = String.fromCharCodes(bytes.take(4));
      expect(header, '%PDF');
    });
  });

  group('Digital Notes Screen Widget Tests', () {
    testWidgets('NotesLibraryScreen renders header, search bar, and notebooks',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final plan = StudyPlan(
        id: 'plan_1',
        title: 'CA Final Master Plan',
        category: 'Professional Exam',
        subjects: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: NotesLibraryScreen(
            studyPlan: plan,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Digital Study Notes'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('New Notebook'), findsOneWidget);
      expect(find.text('All Notebooks'), findsOneWidget);
      expect(find.text('Your Study Notes Library is Empty'), findsOneWidget);
      expect(find.text('Create Your First Note'), findsOneWidget);
    });

    testWidgets(
        'NotesLibraryScreen clicking "Create Your First Note" opens editor directly without dialogs',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: NotesLibraryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create Your First Note'), findsOneWidget);

      // Tap "Create Your First Note"
      await tester.tap(find.text('Create Your First Note'));
      await tester.pumpAndSettle();

      // Should immediately be on the NotebookEditorScreen without any AlertDialog
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(NotebookEditorScreen), findsOneWidget);
      expect(find.byType(RichNotesEditor), findsOneWidget);
    });

    testWidgets(
        'NotesLibraryScreen displays existing notebooks without any starter sample card',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final userNb = Notebook(
        id: 'nb_custom_001',
        title: 'Advanced Auditing SA 700',
        category: 'Auditing',
        pages: [
          NotePage(
            id: 'p1',
            pageNumber: 1,
            title: 'Audit Report Elements',
            content: 'Key Audit Matters summary',
          ),
        ],
      );
      await StorageService.saveNotebook(userNb);

      await tester.pumpWidget(
        const MaterialApp(
          home: NotesLibraryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Displays user notebook
      expect(find.text('Advanced Auditing SA 700'), findsOneWidget);
      // Does NOT display any legacy sample starter card
      expect(find.text('Welcome to Digital Notes 📓'), findsNothing);
      // Since only 1 notebook exists, "Recently Edited" carousel is hidden to prevent duplicate cards
      expect(find.text('Recently Edited'), findsNothing);
    });

    testWidgets('NotesLibraryScreen filters notebooks by search query',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final nb1 = Notebook(
        id: 'nb_audit',
        title: 'Audit Standards SA 500',
        category: 'Professional Exam',
      );
      final nb2 = Notebook(
        id: 'nb_tax',
        title: 'GST Reverse Charge Mechanism',
        category: 'Professional Exam',
      );

      await StorageService.saveNotebook(nb1);
      await StorageService.saveNotebook(nb2);

      await tester.pumpWidget(
        const MaterialApp(
          home: NotesLibraryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Audit Standards SA 500'), findsWidgets);
      expect(find.text('GST Reverse Charge Mechanism'), findsWidgets);

      // Enter search text "GST"
      await tester.enterText(find.byType(TextField), 'GST');
      await tester.pumpAndSettle();

      expect(find.text('GST Reverse Charge Mechanism'), findsOneWidget);
      expect(find.text('Audit Standards SA 500'), findsNothing);
    });

    testWidgets('NotebookEditorScreen loads, displays title and switches modes',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final notebook = Notebook(
        id: 'nb_edit_1',
        title: 'Costing Overhead Variances',
        category: 'College / University',
        pages: [
          NotePage(
            id: 'page_1',
            pageNumber: 1,
            title: 'Variable Overheads',
            content:
                '# Variance Analysis\nFormula = Standard Cost - Actual Cost',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: NotebookEditorScreen(
            notebook: notebook,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Costing Overhead Variances'), findsOneWidget);
      expect(find.text('Variable Overheads'), findsNWidgets(2));

      // Verify Text mode is active by checking RichNotesEditor is present
      expect(find.byType(RichNotesEditor), findsOneWidget);
      expect(find.byType(DrawingCanvasWidget), findsNothing);

      // Switch to Canvas mode via Tooltip
      await tester.tap(find.byTooltip('Handwriting & Drawing'));
      await tester.pumpAndSettle();

      expect(find.byType(DrawingCanvasWidget), findsOneWidget);
      expect(find.byType(RichNotesEditor), findsNothing);
    });

    testWidgets('RichNotesEditor renders Ribbon tabs and switches between them',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RichNotesEditor(
              initialTitle: 'Test Word Editor',
              initialContent:
                  '# Heading 1\n**Bold Text**\n> [!NOTE] Key takeaway',
              onAutoSave: (_, __) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ribbon Tabs are present
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Insert'), findsOneWidget);
      expect(find.text('Layout'), findsOneWidget);
      expect(find.text('Review'), findsOneWidget);

      // Home tab shows formatting buttons
      expect(find.text('H1'), findsOneWidget);
      expect(find.byTooltip('Bold (Ctrl/Cmd+B)'), findsOneWidget);

      // Tap Insert Tab
      await tester.tap(find.text('Insert'));
      await tester.pumpAndSettle();

      expect(find.text('Insert Table'), findsOneWidget);
      expect(find.text('Upload Picture'), findsOneWidget);
      expect(find.text('Math Formula'), findsOneWidget);
      expect(find.text('Study Callout'), findsOneWidget);

      // Tap Layout Tab
      await tester.tap(find.text('Layout'));
      await tester.pumpAndSettle();

      expect(find.text('Size: '), findsOneWidget);
      expect(find.text('Margins: '), findsOneWidget);

      // Tap Review Tab
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();

      expect(find.text('Find & Replace'), findsOneWidget);
      expect(find.text('Word & Doc Stats'), findsOneWidget);
      expect(find.text('Zen Focus Mode'), findsOneWidget);
    });
  });

  group('Word Editor Table, Image, Layout & Shape Models', () {
    test('NoteTable create, addRow, addColumn, removeRow, removeColumn', () {
      final table = NoteTable.create(
          id: 'tbl_test', rows: 2, cols: 2, caption: 'Test Table');
      expect(table.rowCount, 2);
      expect(table.colCount, 2);
      expect(table.caption, 'Test Table');
      expect(table.cells.first.first.isHeader, true);

      // Add Row
      table.addRow();
      expect(table.rowCount, 3);

      // Add Column
      table.addColumn();
      expect(table.colCount, 3);

      // Remove Row
      table.removeRow(2);
      expect(table.rowCount, 2);

      // Remove Column
      table.removeColumn(2);
      expect(table.colCount, 2);

      // Serialization
      final json = table.toJson();
      final restored = NoteTable.fromJson(json);
      expect(restored.id, 'tbl_test');
      expect(restored.caption, 'Test Table');
      expect(restored.rowCount, 2);
      expect(restored.colCount, 2);
    });

    test('NoteImageItem JSON serialization, alignment, and scale', () {
      final img = NoteImageItem(
        id: 'img_test',
        dataBase64:
            'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
        caption: 'Figure 1: Workflow',
        alignment: NoteImageAlignment.right,
        widthScale: 0.5,
      );

      final json = img.toJson();
      final restored = NoteImageItem.fromJson(json);

      expect(restored.id, 'img_test');
      expect(restored.caption, 'Figure 1: Workflow');
      expect(restored.alignment, NoteImageAlignment.right);
      expect(restored.widthScale, 0.5);
      expect(restored.dataBase64.contains('base64'), true);
    });

    test('NotePageLayout DocumentPageSize, orientation, margins', () {
      const layout = NotePageLayout(
        pageSize: DocumentPageSize.letter,
        orientation: DocumentOrientation.landscape,
        margin: DocumentMargin.narrow,
        fontFamily: 'Merriweather',
        fontSize: 16.0,
        lineSpacing: 1.5,
      );

      final json = layout.toJson();
      final restored = NotePageLayout.fromJson(json);

      expect(restored.pageSize, DocumentPageSize.letter);
      expect(restored.orientation, DocumentOrientation.landscape);
      expect(restored.margin, DocumentMargin.narrow);
      expect(restored.margin.padding, 12.0);
      expect(restored.fontFamily, 'Merriweather');
      expect(restored.fontSize, 16.0);
      expect(restored.lineSpacing, 1.5);
    });

    test('DrawingStroke with DrawingShapeType serialization', () {
      const stroke = DrawingStroke(
        id: 'shape_stroke_1',
        points: [
          DrawingPoint(x: 10, y: 10),
          DrawingPoint(x: 100, y: 100),
        ],
        colorValue: 0xFF6C52EE,
        strokeWidth: 2.5,
        tool: DrawingTool.shape,
        shapeType: DrawingShapeType.rectangle,
      );

      final json = stroke.toJson();
      final restored = DrawingStroke.fromJson(json);

      expect(restored.tool, DrawingTool.shape);
      expect(restored.shapeType, DrawingShapeType.rectangle);
      expect(restored.points.length, 2);
    });

    test(
        'RichNotesTextEditingController formats strikethrough, highlights, and equations',
        () {
      final controller = RichNotesTextEditingController(
        text:
            'This is ~~deleted~~ and ==highlighted== and \$E=mc^2\$ with [link](https://flutter.dev)',
      );
      expect(controller.text.contains('~~deleted~~'), true);
      expect(controller.text.contains('==highlighted=='), true);
      expect(controller.text.contains(r'$E=mc^2$'), true);
    });

    test('NotesPdfService generates valid PDF with embedded tables and images',
        () async {
      final page = NotePage(
        id: 'page_table_img',
        pageNumber: 1,
        title: 'Executive Summary',
        content:
            '# Chapter 1: Foundations\n> [!NOTE] Vital concept\n- [ ] Task 1\n- [x] Task 2',
        tables: [
          NoteTable.create(
              id: 'tbl_summary', rows: 2, cols: 2, caption: 'Metrics Table'),
        ],
        images: [
          NoteImageItem(
            id: 'img_sample',
            dataBase64:
                'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
            caption: 'Chart 1',
          ),
        ],
      );

      final nb = Notebook(
        id: 'nb_full_doc',
        title: 'Complete Corporate Strategy',
        category: 'Professional Exam',
        pages: [page],
      );

      final pdfBytes = await NotesPdfService.generateNotebookPdfBytes(nb);
      expect(pdfBytes.isNotEmpty, true);
      final magicHeader = String.fromCharCodes(pdfBytes.take(4));
      expect(magicHeader, '%PDF');
    });
  });
}

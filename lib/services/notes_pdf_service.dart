import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart' show Color;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/note_model.dart';

class NotesPdfService {
  /// Generates a complete PDF document for a given Notebook and opens the
  /// print / save dialog.
  static Future<void> exportNotebook({
    required Notebook notebook,
  }) async {
    final pdfBytes = await generateNotebookPdfBytes(notebook);

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: '${notebook.title.replaceAll(RegExp(r'[^\w\s-]'), '')}_Notes.pdf',
    );
  }

  /// Generates the raw PDF bytes for a Notebook
  static Future<Uint8List> generateNotebookPdfBytes(Notebook notebook) async {
    final doc = pw.Document(
      title: notebook.title,
      author: 'Study Tracker',
      creator: 'Study Tracker Digital Notes',
    );

    final font = await PdfGoogleFonts.poppinsRegular();
    final fontBold = await PdfGoogleFonts.poppinsBold();
    final fontItalic = await PdfGoogleFonts.poppinsItalic();

    // 1. Cover / First Page Header
    for (int i = 0; i < notebook.pages.length; i++) {
      final page = notebook.pages[i];

      PdfPageFormat pageFormat = PdfPageFormat.a4;
      if (page.layout.pageSize == DocumentPageSize.letter) {
        pageFormat = PdfPageFormat.letter;
      }
      if (page.layout.orientation == DocumentOrientation.landscape) {
        pageFormat = pageFormat.landscape;
      }

      final pageMargin = pw.EdgeInsets.all(page.layout.margin.padding);

      doc.addPage(
        pw.MultiPage(
          pageFormat: pageFormat,
          margin: pageMargin,
          theme: pw.ThemeData.withFont(
            base: font,
            bold: fontBold,
            italic: fontItalic,
          ),
          header: (context) => _buildPdfHeader(notebook, page, font, fontBold),
          footer: (context) => _buildPdfFooter(context, font),
          build: (context) {
            return [
              if (i == 0) ...[
                // Notebook Title Banner on first page
                _buildNotebookTitleBanner(notebook, fontBold, font),
                pw.SizedBox(height: 18),
              ],

              // Page Title
              if (page.title.isNotEmpty) ...[
                pw.Text(
                  'Page ${page.pageNumber}: ${page.title}',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 16,
                    color: const PdfColor.fromInt(0xFF1E1D36),
                  ),
                ),
                pw.SizedBox(height: 10),
              ],

              // Formatted Text Content
              if (page.content.isNotEmpty) ...[
                ..._buildTextContent(page.content, font, fontBold, fontItalic),
                pw.SizedBox(height: 16),
              ],

              // Tables
              for (final tbl in page.tables) ...[
                _buildPdfTable(tbl, font, fontBold),
                pw.SizedBox(height: 12),
              ],

              // Images
              for (final img in page.images) ...[
                _buildPdfImage(img, font),
                pw.SizedBox(height: 12),
              ],

              // Drawing / Canvas Strokes (Vector rendered)
              if (page.drawingStrokes.isNotEmpty) ...[
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      vertical: 6, horizontal: 10),
                  decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0xFFF1EDFD),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text(
                    'Handwritten Canvas & Diagrams (${page.drawingStrokes.length} strokes):',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 11,
                      color: const PdfColor.fromInt(0xFF6C52EE),
                    ),
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Container(
                  height: 280,
                  width: double.infinity,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                      color: const PdfColor.fromInt(0xFFEAE5F5),
                      width: 1,
                    ),
                    borderRadius: pw.BorderRadius.circular(8),
                    color: PdfColors.white,
                  ),
                  child: pw.CustomPaint(
                    painter: (PdfGraphics canvas, PdfPoint size) {
                      _paintStrokesToPdf(canvas, size, page.drawingStrokes);
                    },
                  ),
                ),
                pw.SizedBox(height: 16),
              ],
            ];
          },
        ),
      );
    }

    // Fallback if notebook has 0 pages
    if (notebook.pages.isEmpty) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            return pw.Center(
              child: pw.Text(
                'Notebook "${notebook.title}" is currently empty.',
                style: pw.TextStyle(font: font, fontSize: 14),
              ),
            );
          },
        ),
      );
    }

    return doc.save();
  }

  static pw.Widget _buildPdfTable(
    NoteTable table,
    pw.Font font,
    pw.Font fontBold,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (table.caption != null && table.caption!.isNotEmpty) ...[
            pw.Text(
              table.caption!,
              style: pw.TextStyle(
                  font: fontBold, fontSize: 11, color: PdfColors.grey800),
            ),
            pw.SizedBox(height: 4),
          ],
          pw.Table(
            border: pw.TableBorder.all(
              color: const PdfColor.fromInt(0xFFD1D5DB),
              width: 0.8,
            ),
            children: table.cells.map((row) {
              return pw.TableRow(
                children: row.map((cell) {
                  final isHeader = cell.isHeader;
                  return pw.Container(
                    color: isHeader ? const PdfColor.fromInt(0xFFF3F0FC) : null,
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    child: pw.Text(
                      cell.text,
                      style: pw.TextStyle(
                        font: isHeader ? fontBold : font,
                        fontSize: 9,
                        color: isHeader
                            ? const PdfColor.fromInt(0xFF4C389E)
                            : PdfColors.black,
                      ),
                    ),
                  );
                }).toList(),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfImage(NoteImageItem item, pw.Font font) {
    Uint8List? bytes;
    try {
      if (item.dataBase64.contains(',')) {
        final commaIdx = item.dataBase64.indexOf(',');
        final rawBase64 = item.dataBase64.substring(commaIdx + 1);
        bytes = base64Decode(rawBase64);
      } else if (item.dataBase64.isNotEmpty) {
        bytes = base64Decode(item.dataBase64);
      }
    } catch (_) {}

    if (bytes == null || bytes.isEmpty) return pw.SizedBox.shrink();

    final image = pw.MemoryImage(bytes);
    final widthFactor = item.widthScale.clamp(0.2, 1.0);

    pw.Alignment align = pw.Alignment.center;
    if (item.alignment == NoteImageAlignment.left) {
      align = pw.Alignment.centerLeft;
    } else if (item.alignment == NoteImageAlignment.right) {
      align = pw.Alignment.centerRight;
    }

    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 8),
      alignment: align,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.SizedBox(
            width: 400 * widthFactor,
            child: pw.Image(image),
          ),
          if (item.caption.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              item.caption,
              style: pw.TextStyle(
                  font: font, fontSize: 8.5, color: PdfColors.grey700),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildPdfHeader(
    Notebook notebook,
    NotePage page,
    pw.Font font,
    pw.Font fontBold,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom:
              pw.BorderSide(color: PdfColor.fromInt(0xFFEAE5F5), width: 0.8),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            notebook.title,
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 10,
              color: const PdfColor.fromInt(0xFF6C52EE),
            ),
          ),
          pw.Text(
            'Study Tracker Notes • ${DateFormat('d MMM yyyy').format(page.updatedAt)}',
            style: pw.TextStyle(
              font: font,
              fontSize: 9,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfFooter(pw.Context context, pw.Font font) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 14),
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColor.fromInt(0xFFEAE5F5), width: 0.8),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated by Study Tracker',
            style:
                pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style:
                pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildNotebookTitleBanner(
    Notebook notebook,
    pw.Font fontBold,
    pw.Font font,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF5F3FB),
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(
          color: const PdfColor.fromInt(0xFFEAE5F5),
          width: 1,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            notebook.title,
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 20,
              color: const PdfColor.fromInt(0xFF1C1939),
            ),
          ),
          if (notebook.description != null &&
              notebook.description!.trim().isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              notebook.description!.trim(),
              style: pw.TextStyle(
                font: font,
                fontSize: 11,
                color: PdfColors.grey700,
              ),
            ),
          ],
          pw.SizedBox(height: 10),
          pw.Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildBadge(
                  notebook.category, const PdfColor.fromInt(0xFF6C52EE), font),
              if (notebook.subjectName != null)
                _buildBadge(notebook.subjectName!,
                    const PdfColor.fromInt(0xFF2D9CDB), font),
              if (notebook.chapterTitle != null)
                _buildBadge(notebook.chapterTitle!,
                    const PdfColor.fromInt(0xFF10B981), font),
              if (notebook.linkedVideoTitle != null)
                _buildBadge('Class: ${notebook.linkedVideoTitle!}',
                    const PdfColor.fromInt(0xFFE0567A), font),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildBadge(String text, PdfColor color, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: pw.BoxDecoration(
        color: PdfColor(color.red, color.green, color.blue, 0.12),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: color, width: 0.8),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: 9,
          color: color,
        ),
      ),
    );
  }

  static List<pw.Widget> _buildTextContent(
    String content,
    pw.Font font,
    pw.Font fontBold,
    pw.Font fontItalic,
  ) {
    final lines = content.split('\n');
    final List<pw.Widget> widgets = [];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        widgets.add(pw.SizedBox(height: 4));
        continue;
      }

      // Callout alerts
      if (trimmed.startsWith('> [!NOTE]') ||
          trimmed.startsWith('> [!TIP]') ||
          trimmed.startsWith('> [!WARNING]') ||
          trimmed.startsWith('> [!IMPORTANT]')) {
        PdfColor boxBg = const PdfColor.fromInt(0xFFF5F3FF);
        PdfColor barColor = const PdfColor.fromInt(0xFF6C52EE);
        if (trimmed.contains('[!WARNING]')) {
          boxBg = const PdfColor.fromInt(0xFFFFFBEB);
          barColor = const PdfColor.fromInt(0xFFF59E0B);
        } else if (trimmed.contains('[!TIP]')) {
          boxBg = const PdfColor.fromInt(0xFFF0FDF4);
          barColor = const PdfColor.fromInt(0xFF10B981);
        } else if (trimmed.contains('[!IMPORTANT]')) {
          boxBg = const PdfColor.fromInt(0xFFFEF2F2);
          barColor = const PdfColor.fromInt(0xFFEF4444);
        }

        widgets.add(pw.Container(
          margin: const pw.EdgeInsets.symmetric(vertical: 4),
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: pw.BoxDecoration(
            color: boxBg,
            border: pw.Border(left: pw.BorderSide(color: barColor, width: 3)),
          ),
          child: pw.Text(
            trimmed.substring(2),
            style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: barColor),
          ),
        ));
        continue;
      }

      if (trimmed.startsWith('# ')) {
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8, bottom: 4),
          child: pw.Text(
            trimmed.substring(2),
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 16,
              color: const PdfColor.fromInt(0xFF1C1939),
            ),
          ),
        ));
      } else if (trimmed.startsWith('## ')) {
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 6, bottom: 3),
          child: pw.Text(
            trimmed.substring(3),
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 13,
              color: const PdfColor.fromInt(0xFF6C52EE),
            ),
          ),
        ));
      } else if (trimmed.startsWith('### ')) {
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4, bottom: 2),
          child: pw.Text(
            trimmed.substring(4),
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 11,
              color: const PdfColor.fromInt(0xFF2D9CDB),
            ),
          ),
        ));
      } else if (trimmed.startsWith('• ') || trimmed.startsWith('- ')) {
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(left: 12, bottom: 3),
          child: pw.Bullet(
            text: trimmed.substring(2),
            style: pw.TextStyle(font: font, fontSize: 10),
            bulletColor: const PdfColor.fromInt(0xFF6C52EE),
          ),
        ));
      } else if (trimmed.startsWith('> ')) {
        widgets.add(pw.Container(
          margin: const pw.EdgeInsets.symmetric(vertical: 4),
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: const pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFF1EDFD),
            border: pw.Border(
              left:
                  pw.BorderSide(color: PdfColor.fromInt(0xFF6C52EE), width: 3),
            ),
          ),
          child: pw.Text(
            trimmed.substring(2),
            style: pw.TextStyle(
                font: fontItalic, fontSize: 10, color: PdfColors.grey800),
          ),
        ));
      } else {
        final cleanText = trimmed.replaceAll(RegExp(r'[*_`]'), '');
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Text(
            cleanText,
            style: pw.TextStyle(font: font, fontSize: 10, lineSpacing: 2),
          ),
        ));
      }
    }

    return widgets;
  }

  static void _paintStrokesToPdf(
    PdfGraphics canvas,
    PdfPoint size,
    List<DrawingStroke> strokes,
  ) {
    if (strokes.isEmpty) return;

    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;

    for (final s in strokes) {
      for (final p in s.points) {
        if (p.x < minX) minX = p.x;
        if (p.y < minY) minY = p.y;
        if (p.x > maxX) maxX = p.x;
        if (p.y > maxY) maxY = p.y;
      }
    }

    if (minX.isInfinite || maxX.isInfinite) return;

    final strokeWidth = maxX - minX;
    final strokeHeight = maxY - minY;

    final double scaleX = strokeWidth > 0 ? (size.x - 20) / strokeWidth : 1.0;
    final double scaleY = strokeHeight > 0 ? (size.y - 20) / strokeHeight : 1.0;
    final double scale = [scaleX, scaleY, 1.0].reduce((a, b) => a < b ? a : b);

    canvas.saveContext();

    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;

      final color = Color(stroke.colorValue);
      canvas.setColor(PdfColor(
        color.r,
        color.g,
        color.b,
        stroke.opacity,
      ));
      canvas.setLineWidth(stroke.strokeWidth * scale);

      final first = stroke.points.first;
      final pdfX = 10 + (first.x - minX) * scale;
      final pdfY = size.y - 10 - (first.y - minY) * scale;
      canvas.moveTo(pdfX, pdfY);

      for (int i = 1; i < stroke.points.length; i++) {
        final p = stroke.points[i];
        final px = 10 + (p.x - minX) * scale;
        final py = size.y - 10 - (p.y - minY) * scale;
        canvas.lineTo(px, py);
      }
      canvas.strokePath();
    }

    canvas.restoreContext();
  }
}

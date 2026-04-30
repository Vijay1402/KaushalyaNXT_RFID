import 'dart:io';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'analytics_pdf_export_data.dart';

const MethodChannel _fileSaveChannel = MethodChannel(
  'com.example.kaushalyanxt_rfid/files',
);

Future<String?> exportFarmManagerAnalyticsPdf(
  FarmManagerAnalyticsExportData data,
) async {
  final document = pw.Document();
  final formatter = DateFormat('dd MMM yyyy, hh:mm a');

  document.addPage(
    pw.MultiPage(
      margin: const pw.EdgeInsets.all(24),
      build: (context) => [
        pw.Text(
          'Farm Manager Analytics',
          style: pw.TextStyle(
            fontSize: 22,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text('Manager: ${data.managerName}'),
        pw.Text('Generated: ${formatter.format(data.generatedAt)}'),
        pw.Text('Range: ${data.rangeLabel}'),
        pw.Text('Farm Scope: ${data.farmLabel}'),
        pw.Text('Health View: ${data.healthModeLabel}'),
        pw.SizedBox(height: 16),
        _summaryTable(data),
        if (data.note.trim().isNotEmpty) ...[
          pw.SizedBox(height: 14),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: const PdfColor(0.96, 0.98, 0.96),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(data.note),
          ),
        ],
        pw.SizedBox(height: 18),
        _section(
          title: 'Trend Highlights',
          rows: data.trendHighlights,
        ),
        pw.SizedBox(height: 18),
        _section(
          title: 'Farm Highlights',
          rows: data.farmHighlights,
        ),
        pw.SizedBox(height: 18),
        _section(
          title: 'Issue Highlights',
          rows: data.issueHighlights,
        ),
      ],
    ),
  );

  final timestamp = DateFormat('yyyyMMdd_HHmmss').format(data.generatedAt);
  final fileName = 'farm_manager_analytics_$timestamp.pdf';
  final pdfBytes = await document.save();

  if (Platform.isAndroid) {
    try {
      final savedLocation = await _fileSaveChannel.invokeMethod<String>(
        'saveBytesToDownloads',
        <String, dynamic>{
          'fileName': fileName,
          'mimeType': 'application/pdf',
          'bytes': pdfBytes,
        },
      );
      if (savedLocation != null && savedLocation.trim().isNotEmpty) {
        return savedLocation;
      }
    } on PlatformException {
      // Fall back to a filesystem-based export when the platform save fails.
    }
  }

  final downloadsDirectory = await getDownloadsDirectory();
  final exportDirectory =
      downloadsDirectory ?? await getApplicationDocumentsDirectory();
  if (!await exportDirectory.exists()) {
    await exportDirectory.create(recursive: true);
  }

  final file = File('${exportDirectory.path}/$fileName');
  await file.writeAsBytes(pdfBytes);
  return file.path;
}

pw.Widget _summaryTable(FarmManagerAnalyticsExportData data) {
  return pw.Table(
    border: pw.TableBorder.all(
      color: const PdfColor(0.82, 0.86, 0.82),
    ),
    children: [
      _summaryRow('Managed Farms', '${data.totalFarms}'),
      _summaryRow('Visible Trees', '${data.totalTrees}'),
      _summaryRow(
        'Average Yield',
        '${data.averageYieldKg.toStringAsFixed(1)} kg',
      ),
      _summaryRow('Healthy Trees', '${data.healthyTrees}'),
      _summaryRow('Needs Attention', '${data.needsAttentionTrees}'),
      _summaryRow('Critical Trees', '${data.criticalTrees}'),
      _summaryRow('Visible Issues', '${data.totalIssues}'),
      _summaryRow('Critical Issues', '${data.criticalIssues}'),
      _summaryRow('Trend Metric', data.trendUnitLabel),
    ],
  );
}

pw.TableRow _summaryRow(String label, String value) {
  return pw.TableRow(
    children: [
      pw.Padding(
        padding: const pw.EdgeInsets.all(10),
        child: pw.Text(
          label,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.all(10),
        child: pw.Text(value),
      ),
    ],
  );
}

pw.Widget _section({
  required String title,
  required List<FarmManagerAnalyticsExportRow> rows,
}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 16,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
      pw.SizedBox(height: 8),
      if (rows.isEmpty)
        pw.Text('No items available.')
      else
        ...rows.map(
          (row) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '${row.label}: ${row.value}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                if (row.detail.trim().isNotEmpty) pw.Text(row.detail),
              ],
            ),
          ),
        ),
    ],
  );
}

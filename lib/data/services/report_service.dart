import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReportService {
  static Future<void> generateAttendanceReport({
    required String teacherName,
    required String section,
    required List<Map<String, dynamic>> records,
  }) async {
    final pdf = pw.Document();

    // Format local date with milliseconds (yyyy-MM-dd HH:mm:ss.SSS)
    final nowStr = DateTime.now().toString();
    final dateGenStr = nowStr.length >= 23 ? nowStr.substring(0, 23) : nowStr;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Autodemy Attendance Report',
                style: pw.TextStyle(
                  fontSize: 26,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Container(
                height: 1.5,
                color: PdfColors.black,
              ),
              pw.SizedBox(height: 15),
              pw.Text(
                'Teacher: $teacherName',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.Text(
                'Section: $section',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.Text(
                'Date Generated: $dateGenStr',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 25),
              pw.TableHelper.fromTextArray(
                context: context,
                data: <List<String>>[
                  <String>['Student Name', 'Status', 'Time In'],
                  ...records.map((r) => [
                        r['studentName']?.toString() ?? 'N/A',
                        r['status']?.toString().toUpperCase() ?? 'N/A',
                        r['timein']?.toString() ?? 'N/A'
                      ]),
                ],
                border: pw.TableBorder.all(
                  color: PdfColors.black,
                  width: 1.0,
                ),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 12,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                cellStyle: const pw.TextStyle(
                  fontSize: 11,
                ),
                cellPadding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3.0),
                  1: const pw.FlexColumnWidth(1.2),
                  2: const pw.FlexColumnWidth(1.2),
                },
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                  2: pw.Alignment.center,
                },
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }
}

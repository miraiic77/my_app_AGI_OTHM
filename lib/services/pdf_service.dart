import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
  static Future<void> generateStudentAttendanceReport(
    List<Map<String, dynamic>> records,
    String startDate,
    String endDate,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            _buildHeader(),
            pw.SizedBox(height: 20),
            _buildTitle('Student Attendance Report'),
            pw.SizedBox(height: 10),
            _buildDateRange(startDate, endDate),
            pw.SizedBox(height: 20),
            _buildStudentTable(records),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'student_attendance_report_${startDate}_to_${endDate}.pdf',
    );
  }

  static Future<void> generateFacultyAttendanceReport(
    List<Map<String, dynamic>> records,
    String startDate,
    String endDate,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            _buildHeader(),
            pw.SizedBox(height: 20),
            _buildTitle('Faculty Attendance Report'),
            pw.SizedBox(height: 10),
            _buildDateRange(startDate, endDate),
            pw.SizedBox(height: 20),
            _buildFacultyTable(records),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'faculty_attendance_report_${startDate}_to_${endDate}.pdf',
    );
  }

  static pw.Widget _buildHeader() {
    return pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(color: PdfColors.blue),
      child: pw.Text(
        'Attendance Management System',
        style: pw.TextStyle(color: PdfColors.white, fontSize: 24, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _buildTitle(String title) {
    return pw.Text(title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold));
  }

  static pw.Widget _buildDateRange(String start, String end) {
    return pw.Text('Period: $start to $end', style: const pw.TextStyle(fontSize: 12));
  }

  static pw.Widget _buildStudentTable(List<Map<String, dynamic>> records) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        // Header Row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue50),
          children: [
            _buildTableCell('Date', true),
            _buildTableCell('Student Name', true),
            _buildTableCell('Roll Number', true),
            _buildTableCell('Batch', true),
            _buildTableCell('Status', true),
          ],
        ),
        // Data Rows
        ...records.map((record) {
          return pw.TableRow(
            children: [
              _buildTableCell(record['Date'] ?? '', false),
              _buildTableCell(record['Student Name'] ?? '', false),
              _buildTableCell(record['Roll Number'] ?? '', false),
              _buildTableCell(record['Batch'] ?? '', false),
              _buildTableCell(record['Status'] ?? '', false),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildFacultyTable(List<Map<String, dynamic>> records) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        // Header Row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue50),
          children: [
            _buildTableCell('Date', true),
            _buildTableCell('Faculty Name', true),
            _buildTableCell('Subject', true),
            _buildTableCell('Status', true),
          ],
        ),
        // Data Rows
        ...records.map((record) {
          return pw.TableRow(
            children: [
              _buildTableCell(record['Date'] ?? '', false),
              _buildTableCell(record['Faculty Name'] ?? '', false),
              _buildTableCell(record['Subject'] ?? '', false),
              _buildTableCell(record['Status'] ?? '', false),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildTableCell(String text, bool isHeader) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: isHeader ? 12 : 10,
        ),
      ),
    );
  }
}
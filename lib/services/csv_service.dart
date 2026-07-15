import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import 'package:universal_html/html.dart' as html;

class CsvService {
  // --- FILE PICKERS ---
  static Future<String?> pickCsvFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result != null && result.files.single.bytes != null) {
      return String.fromCharCodes(result.files.single.bytes!);
    } else if (result != null && result.files.single.path != null) {
      return await File(result.files.single.path!).readAsString();
    }
    return null;
  }

  static Future<PlatformFile?> pickExcelFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );
    return result?.files.single;
  }

  // --- PARSERS ---
  static List<Map<String, dynamic>> parseCsv(String csvData) {
    List<List<dynamic>> rows = const CsvToListConverter(eol: '\n').convert(csvData);
    if (rows.isEmpty) return [];
    
    List<String> headers = rows.first.map((e) => e.toString().trim()).toList();
    List<Map<String, dynamic>> records = [];
    
    for (var i = 1; i < rows.length; i++) {
      Map<String, dynamic> record = {};
      for (var j = 0; j < headers.length; j++) {
        record[headers[j]] = j < rows[i].length ? rows[i][j].toString().trim() : '';
      }
      records.add(record);
    }
    return records;
  }

  static List<Map<String, dynamic>> parseExcel(PlatformFile file) {
    Uint8List? bytes = file.bytes;
    if (bytes == null && file.path != null) {
      bytes = File(file.path!).readAsBytesSync();
    }
    if (bytes == null) return [];

    var decoder = SpreadsheetDecoder.decodeBytes(bytes);
    List<Map<String, dynamic>> records = [];
    
    if (decoder.tables.isEmpty) return records;

    var sheet = decoder.tables.keys.first;
    var table = decoder.tables[sheet]!;
    
    if (table.maxRows == 0 || table.maxCols == 0) return records;

    List<String> headers = [];
    for (var i = 0; i < table.maxCols; i++) {
      headers.add(table.rows[0][i]?.toString().trim() ?? 'Column$i');
    }

    for (var i = 1; i < table.maxRows; i++) {
      Map<String, dynamic> record = {};
      bool hasData = false;
      for (var j = 0; j < table.maxCols; j++) {
        var value = table.rows[i][j]?.toString().trim() ?? '';
        record[headers[j]] = value;
        if (value.isNotEmpty) hasData = true;
      }
      if (hasData) records.add(record);
    }
    
    return records;
  }

  // --- EXPORTERS ---
  static String convertToCsv(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return '';
    List<String> headers = data.first.keys.toList();
    List<List<dynamic>> rows = [headers];
    
    for (var record in data) {
      rows.add(headers.map((h) => record[h] ?? '').toList());
    }
    
    return const ListToCsvConverter().convert(rows);
  }

  static void downloadCsv(String csvData, String fileName) {
    final bytes = utf8.encode(csvData);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.document.createElement('a') as html.AnchorElement
      ..href = url
      ..style.display = 'none'
      ..download = fileName;
    html.document.body!.children.add(anchor);
    anchor.click();
    html.document.body!.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/csv_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FacultyAttendanceScreen extends StatefulWidget {
  const FacultyAttendanceScreen({super.key});

  @override
  State<FacultyAttendanceScreen> createState() => _FacultyAttendanceScreenState();
}

class _FacultyAttendanceScreenState extends State<FacultyAttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isSaving = false;

  Map<String, String> _attendanceStatus = {};
  List<Map<String, dynamic>> _faculties = [];

  Future<void> _loadFaculties() async {
    setState(() => _isLoading = true);
    _attendanceStatus.clear();
    _faculties.clear();

    try {
      final facultiesSnapshot = await FirebaseFirestore.instance.collection('faculties').orderBy('name').get();
      for (var doc in facultiesSnapshot.docs) {
        final data = doc.data();
        _faculties.add({'id': doc.id, 'name': data['name'] ?? '', 'subject': data['subject'] ?? '', 'email': data['email'] ?? ''});
        _attendanceStatus[doc.id] = 'Present';
      }

      final dateStr = _formatDate(_selectedDate);
      final existingAttendance = await FirebaseFirestore.instance.collection('faculty_attendance').where('date', isEqualTo: dateStr).get();
      if (existingAttendance.docs.isNotEmpty) {
        for (var doc in existingAttendance.docs) {
          final data = doc.data();
          final facultyId = data['facultyId'];
          if (facultyId != null) _attendanceStatus[facultyId] = data['status'] ?? 'Present';
        }
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Attendance already marked for this date. You can update it.'), backgroundColor: Colors.orange));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading faculty: $e')));
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveAttendance() async {
    if (_faculties.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No faculty members to mark attendance for'))); return; }
    bool? confirm = await showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Save Attendance'), content: Text('Save attendance for ${_faculties.length} faculty members on ${_formatDate(_selectedDate)}?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save'))]));
    if (confirm != true) return;
    setState(() => _isSaving = true);

        try {
      final dateStr = _formatDate(_selectedDate);
      final currentUser = FirebaseAuth.instance.currentUser;
      
      // Delete existing attendance for this date
      final existing = await FirebaseFirestore.instance
          .collection('faculty_attendance')
          .where('date', isEqualTo: dateStr)
          .get();
      for (var doc in existing.docs) await doc.reference.delete();

      final batch = FirebaseFirestore.instance.batch();
      for (var faculty in _faculties) {
        final status = _attendanceStatus[faculty['id']] ?? 'Present';
        final docRef = FirebaseFirestore.instance.collection('faculty_attendance').doc();
        
        // ONLY THIS BATCH.SET IS NEEDED:
        batch.set(docRef, {
          'date': dateStr,
          'facultyId': faculty['id'],
          'facultyName': faculty['name'],
          'subject': faculty['subject'],
          'status': status,
          'markedBy': currentUser?.email ?? 'Unknown',
          'markedAt': Timestamp.now(),
          'syncedToSheet': false, 
        });
      }
      
      // ONLY ONE COMMIT IS NEEDED:
      await batch.commit();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Faculty attendance saved!'), backgroundColor: Colors.green),
        );
      }

      // --- NEW: Send to Google Sheets ---
      
      // ----------------------------------

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Faculty attendance saved and synced!'), backgroundColor: Colors.green, duration: const Duration(seconds: 2)));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Faculty attendance saved for ${_faculties.length} members!'), backgroundColor: Colors.green, duration: const Duration(seconds: 2)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e')));
    }
    setState(() => _isSaving = false);
  }

  Future<void> _exportAttendance() async {
    if (_faculties.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No data to export'))); return; }
    try {
      List<Map<String, dynamic>> records = _faculties.map((f) => {'Date': _formatDate(_selectedDate), 'Faculty Name': f['name'], 'Subject': f['subject'], 'Status': _attendanceStatus[f['id']] ?? 'Present'}).toList();
      String csv = CsvService.convertToCsv(records);
      CsvService.downloadCsv(csv, 'faculty_attendance_${_formatDate(_selectedDate)}.csv');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exported successfully!')));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'))); }
  }

  Future<void> _importAttendance() async {
    try {
      String? csvData = await CsvService.pickCsvFile();
      if (csvData == null) return;
      List<Map<String, dynamic>> records = CsvService.parseCsv(csvData);
      int updatedCount = 0;
      int notFoundCount = 0;
      List<String> notFoundNames = [];

      for (var record in records) {
        String name = (record['Name'] ?? '').toString().toLowerCase().trim();
        String email = (record['Email'] ?? '').toString().toLowerCase().trim();
        String status = (record['Status'] ?? 'Present').toString().toLowerCase().trim();
        if (status == 'p' || status == 'Present') status = 'Present';
        else if (status == 'a' || status == 'Absent') status = 'Absent';
        else if (status == 'l' || status == 'Absent') status = 'Absent';
        else status = 'Present';

        bool found = false;
        for (var faculty in _faculties) {
          String fName = (faculty['name'] ?? '').toString().toLowerCase().trim();
          String fEmail = (faculty['email'] ?? '').toString().toLowerCase().trim();
          if ((name.isNotEmpty && fName == name) || (name.isNotEmpty && fName.contains(name)) || (email.isNotEmpty && fEmail == email)) {
            _attendanceStatus[faculty['id']] = status;
            updatedCount++;
            found = true;
            break;
          }
        }
        if (!found) { notFoundCount++; notFoundNames.add(name.isNotEmpty ? name : (email.isNotEmpty ? email : 'Unknown')); }
      }

      if (mounted) {
        String message = '✅ Updated: $updatedCount faculty';
        if (notFoundCount > 0) message += '\n⚠️ Not found: $notFoundCount (${notFoundNames.take(3).join(", ")})';
        showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Import Results'), content: Text(message), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))]));
        setState(() {});
      }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import error: $e'))); }
  }

  void _markAllPresent() { setState(() { for (var faculty in _faculties) _attendanceStatus[faculty['id']] = 'Present'; }); }
  void _markAllAbsent() { setState(() { for (var faculty in _faculties) _attendanceStatus[faculty['id']] = 'Absent'; }); }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
    if (picked != null && picked != _selectedDate) { setState(() => _selectedDate = picked); _loadFaculties(); }
  }

  String _formatDate(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  int _countByStatus(String status) => _attendanceStatus.values.where((s) => s == status).length;

  @override
  void initState() { super.initState(); _loadFaculties(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Faculty Attendance'), backgroundColor: Colors.red, foregroundColor: Colors.white, actions: [IconButton(icon: const Icon(Icons.file_upload), tooltip: 'Import CSV', onPressed: _importAttendance), IconButton(icon: const Icon(Icons.file_download), tooltip: 'Export CSV', onPressed: _exportAttendance)]),
      body: Column(
        children: [
          Container(padding: const EdgeInsets.all(16), color: Colors.red.shade50, child: const Row(children: [Icon(Icons.school, color: Colors.red, size: 32), SizedBox(width: 12), Text('Mark Faculty Attendance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))])),
          Container(padding: const EdgeInsets.all(16), color: Colors.grey.shade100, child: InkWell(onTap: _pickDate, child: InputDecorator(decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder(), filled: true, fillColor: Colors.white, suffixIcon: Icon(Icons.calendar_today)), child: Text(_formatDate(_selectedDate))))),
          if (_faculties.isNotEmpty) Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), color: Colors.white, child: Row(children: [_buildStatusChip('Present', _countByStatus('Present'), Colors.green), const SizedBox(width: 8), _buildStatusChip('Absent', _countByStatus('Absent'), Colors.red), const SizedBox(width: 8), _buildStatusChip('Absent', _countByStatus('Absent'), Colors.orange), const Spacer(), TextButton.icon(onPressed: _markAllPresent, icon: const Icon(Icons.check, size: 18), label: const Text('All Present')), TextButton.icon(onPressed: _markAllAbsent, icon: const Icon(Icons.close, size: 18), label: const Text('All Absent'))])),
          Expanded(
            child: _isLoading ? const Center(child: CircularProgressIndicator())
            : _faculties.isEmpty ? const Center(child: Text('No faculty members found. Add some first!', style: TextStyle(color: Colors.grey, fontSize: 16)))
            : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _faculties.length,
                itemBuilder: (context, index) {
                  final faculty = _faculties[index];
                  final status = _attendanceStatus[faculty['id']] ?? 'Present';
                  return Card(
  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
  child: Padding(
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: _getStatusColor(status).withOpacity(0.2),
          child: Text((faculty['name'] ?? '?')[0].toUpperCase(), style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 12),
        // ✅ FIXED: Use Expanded and Column for mobile-friendly layout
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                faculty['name'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 4),
              Text(
                'Subject: ${faculty['subject'] ?? 'N/A'}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
        // ✅ FIXED: Status toggle buttons stay on the right
        _buildStatusToggle(faculty['id'], status),
      ],
    ),
  ),
);
                },
              ),
          ),
          if (_faculties.isNotEmpty) Container(padding: const EdgeInsets.all(16), color: Colors.white, child: SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveAttendance,
            icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
            label: Text(_isSaving ? 'Saving...' : 'Save Attendance (${_faculties.length} faculty)', style: const TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ))),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, int count, Color color) { return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color)), child: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 6), Text('$count $label', style: TextStyle(color: color, fontWeight: FontWeight.bold))])); }
  Widget _buildStatusToggle(String facultyId, String currentStatus) { return Row(mainAxisSize: MainAxisSize.min, children: [_buildStatusButton(facultyId, 'Present', 'P', Colors.green, currentStatus), const SizedBox(width: 4), _buildStatusButton(facultyId, 'Absent', 'A', Colors.red, currentStatus), const SizedBox(width: 4), _buildStatusButton(facultyId, 'Absent', 'L', Colors.orange, currentStatus)]); }
  Widget _buildStatusButton(String facultyId, String status, String label, Color color, String currentStatus) { final isSelected = currentStatus == status; return InkWell(onTap: () { setState(() { _attendanceStatus[facultyId] = status; }); }, child: Container(width: 36, height: 36, decoration: BoxDecoration(color: isSelected ? color : Colors.grey.shade200, borderRadius: BorderRadius.circular(8), border: Border.all(color: isSelected ? color : Colors.grey.shade400)), child: Center(child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade700, fontWeight: FontWeight.bold))))); }
  Color _getStatusColor(String status) { switch (status) { case 'Present': return Colors.green; case 'Absent': return Colors.red; case 'Absent': return Colors.orange; default: return Colors.grey; } }
}
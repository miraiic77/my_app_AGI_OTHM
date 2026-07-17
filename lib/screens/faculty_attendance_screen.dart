import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FacultyAttendanceScreen extends StatefulWidget {
  const FacultyAttendanceScreen({super.key});

  @override
  State<FacultyAttendanceScreen> createState() => _FacultyAttendanceScreenState();
}

class _FacultyAttendanceScreenState extends State<FacultyAttendanceScreen> {
  String _selectedSession = 'SESS1'; // Default to morning session
  final List<String> _sessions = ['SESS1', 'SESS2'];
  
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isSaving = false;
  
  Map<String, String> _attendanceStatus = {};
  List<Map<String, dynamic>> _faculties = [];

  final List<Map<String, String>> _attendanceStatuses = [
    {'label': 'P', 'value': 'Present', 'full': 'Present'},
    {'label': 'A', 'value': 'Absent', 'full': 'Absent'},
    {'label': 'OFF', 'value': 'Off', 'full': 'Off'},
    {'label': 'H', 'value': 'Holiday', 'full': 'Holiday'},
    {'label': 'CC', 'value': 'Course Completed', 'full': 'Course Completed'},
    {'label': 'NS', 'value': 'Not Started', 'full': 'Not Started'},
  ];

  @override
  void initState() {
    super.initState();
    _loadFaculties();
  }

  Future<void> _loadFaculties() async {
    setState(() => _isLoading = true);
    _attendanceStatus.clear();
    _faculties.clear();

    try {
      final facultySnapshot = await FirebaseFirestore.instance
          .collection('faculties')
          .orderBy('name')
          .get();

      for (var doc in facultySnapshot.docs) {
        final data = doc.data();
        _faculties.add({
          'id': doc.id,
          'name': data['name'] ?? '',
          'email': data['email'] ?? '',
          'phone': data['phone'] ?? '',
          'subject': data['subject'] ?? '',
        });
        _attendanceStatus[doc.id] = 'Present';
      }

      final dateStr = _formatDate(_selectedDate);
      
      // ✅ FILTER BY SESSION
      final existingAttendance = await FirebaseFirestore.instance
          .collection('faculty_attendance')
          .where('date', isEqualTo: dateStr)
          .where('session', isEqualTo: _selectedSession)
          .get();

      if (existingAttendance.docs.isNotEmpty) {
        for (var doc in existingAttendance.docs) {
          final data = doc.data();
          final facultyId = data['facultyId'];
          if (facultyId != null) {
            _attendanceStatus[facultyId] = data['status'] ?? 'Present';
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ $_selectedSession Faculty attendance already marked for this date. You can update it.'), 
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading faculty: $e')));
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveAttendance() async {
    if (_faculties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No faculty to mark attendance for')));
      return;
    }

    final dateStr = _formatDate(_selectedDate);
    
    // ✅ CHECK EXISTING RECORDS FOR THIS SPECIFIC SESSION
    final existing = await FirebaseFirestore.instance
        .collection('faculty_attendance')
        .where('date', isEqualTo: dateStr)
        .where('session', isEqualTo: _selectedSession)
        .get();

    if (existing.docs.isNotEmpty) {
      bool? confirm = await showDialog(context: context, builder: (ctx) => AlertDialog(
        title: const Text('⚠️ Attendance Already Marked'),
        content: Text('$_selectedSession faculty attendance for ${_faculties.length} staff on ${dateStr} already exists. Do you want to UPDATE it?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Update Anyway'),
          ),
        ],
      ));

      if (confirm != true) return;
    } else {
      bool? confirm = await showDialog(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Save Attendance'),
        content: Text('Save $_selectedSession faculty attendance for ${_faculties.length} staff on ${dateStr}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ));

      if (confirm != true) return;
    }

    setState(() => _isSaving = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;

      if (existing.docs.isNotEmpty) {
        for (var doc in existing.docs) await doc.reference.delete();
      }

      final batch = FirebaseFirestore.instance.batch();
      for (var faculty in _faculties) {
        final status = _attendanceStatus[faculty['id']] ?? 'Present';
        final docRef = FirebaseFirestore.instance.collection('faculty_attendance').doc();
        batch.set(docRef, {
          'date': dateStr,
          'session': _selectedSession, // ✅ SAVE SESSION TO DATABASE
          'facultyId': faculty['id'],
          'facultyName': faculty['name'],
          'email': faculty['email'],
          'subject': faculty['subject'],
          'status': status,
          'markedBy': currentUser?.email ?? 'Unknown',
          'markedAt': Timestamp.now(),
          'syncedToSheet': false,
        });
      }
      
      await batch.commit();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(existing.docs.isNotEmpty 
                ? '✅ $_selectedSession Faculty attendance updated successfully!' 
                : '✅ $_selectedSession Faculty attendance saved successfully!'), 
            backgroundColor: Colors.green,
          ),
        );
        _loadFaculties(); // Reload to refresh UI
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    }
    
    if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  void _markAllStatus(String status) { 
    setState(() { 
      for (var faculty in _faculties) {
        _attendanceStatus[faculty['id']] = status; 
      }
    }); 
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context, 
      initialDate: _selectedDate, 
      firstDate: DateTime(2020), 
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadFaculties();
    }
  }

  String _formatDate(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  int _countByStatus(String status) => _attendanceStatus.values.where((s) => s.toLowerCase() == status.toLowerCase()).length;

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) { 
      case 'present': return Colors.green; 
      case 'absent': return Colors.red; 
      case 'off': return Colors.blue; 
      case 'holiday': return Colors.orange; 
      case 'course completed': return Colors.teal; 
      case 'not started': return Colors.grey; 
      default: return Colors.grey; 
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Faculty Attendance'), 
        backgroundColor: Colors.red, 
        foregroundColor: Colors.white
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16), 
            color: Colors.red.shade50, 
            child: const Row(
              children: [
                Icon(Icons.school, color: Colors.red, size: 32), 
                SizedBox(width: 12), 
                Text('Mark Faculty Attendance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))
              ]
            )
          ),
          Container(
            padding: const EdgeInsets.all(16), 
            color: Colors.grey.shade100,
            child: Column(
              children: [
                InkWell(
                  onTap: _pickDate, 
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date', 
                      border: OutlineInputBorder(), 
                      filled: true, 
                      fillColor: Colors.white, 
                      suffixIcon: Icon(Icons.calendar_today)
                    ), 
                    child: Text(_formatDate(_selectedDate))
                  )
                ),
                const SizedBox(height: 12),
                // ✅ NEW: SESSION SELECTOR
                DropdownButtonFormField<String>(
                  value: _selectedSession,
                  decoration: const InputDecoration(
                    labelText: 'Session *',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: _sessions.map((session) {
                    String label = session == 'SESS1' ? 'SESS1 (Morning)' : 'SESS2 (Afternoon)';
                    return DropdownMenuItem(value: session, child: Text(label));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedSession = value!;
                    });
                    _loadFaculties();
                  },
                ),
              ]
            ),
          ),
          if (_faculties.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), 
              color: Colors.white, 
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildStatusChip('Present', _countByStatus('Present'), Colors.green), 
                    const SizedBox(width: 8),
                    _buildStatusChip('Absent', _countByStatus('Absent'), Colors.red), 
                    const SizedBox(width: 8),
                    _buildStatusChip('Off', _countByStatus('Off'), Colors.blue), 
                    const SizedBox(width: 8),
                    _buildStatusChip('Holiday', _countByStatus('Holiday'), Colors.orange), 
                    const SizedBox(width: 8),
                    _buildStatusChip('Course Completed', _countByStatus('Course Completed'), Colors.teal), 
                    const SizedBox(width: 8),
                    _buildStatusChip('Not Started', _countByStatus('Not Started'), Colors.grey), 
                    const SizedBox(width: 16),
                    TextButton.icon(
                      onPressed: () => _markAllStatus('Present'), 
                      icon: const Icon(Icons.check, size: 18), 
                      label: const Text('All Present')
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _markAllStatus('Absent'), 
                      icon: const Icon(Icons.close, size: 18), 
                      label: const Text('All Absent')
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _markAllStatus('Off'), 
                      icon: const Icon(Icons.block, size: 18), 
                      label: const Text('All Off')
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _markAllStatus('Holiday'), 
                      icon: const Icon(Icons.celebration, size: 18), 
                      label: const Text('All Holiday')
                    ),
                  ]
                ),
              ),
            ),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _faculties.isEmpty 
                ? const Center(child: Text('No faculty found', style: TextStyle(color: Colors.grey, fontSize: 16)))
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _faculties.length,
                    itemBuilder: (context, index) {
                      final faculty = _faculties[index];
                      final status = _attendanceStatus[faculty['id']] ?? 'Present';
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: _getStatusColor(status).withOpacity(0.2), 
                                child: Text(
                                  (faculty['name'] ?? '?')[0].toUpperCase(), 
                                  style: TextStyle(
                                    color: _getStatusColor(status), 
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      faculty['name'] ?? '', 
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold, 
                                        fontSize: 13,
                                      ), 
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Subject: ${faculty['subject'] ?? 'N/A'}', 
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              _buildCompactStatusButtons(faculty['id'], status),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_faculties.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16), 
              color: Colors.white, 
              child: SizedBox(
                width: double.infinity, 
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveAttendance,
                  icon: _isSaving 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                    : const Icon(Icons.save),
                  label: Text(
                    _isSaving ? 'Saving...' : 'Save $_selectedSession Attendance (${_faculties.length} staff)', 
                    style: const TextStyle(fontSize: 16)
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, 
                    foregroundColor: Colors.white, 
                    padding: const EdgeInsets.symmetric(vertical: 16), 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                )
              )
            ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), 
      decoration: BoxDecoration(
        color: color.withOpacity(0.1), 
        borderRadius: BorderRadius.circular(20), 
        border: Border.all(color: color)
      ), 
      child: Row(
        mainAxisSize: MainAxisSize.min, 
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), 
          const SizedBox(width: 6), 
          Text('$count $label', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11))
        ]
      )
    );
  }

  Widget _buildCompactStatusButtons(String facultyId, String currentStatus) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildCompactButton(facultyId, 'Present', 'P', Colors.green, currentStatus),
        const SizedBox(width: 2),
        _buildCompactButton(facultyId, 'Absent', 'A', Colors.red, currentStatus),
        const SizedBox(width: 2),
        _buildCompactButton(facultyId, 'Off', 'OFF', Colors.blue, currentStatus),
        const SizedBox(width: 2),
        _buildCompactButton(facultyId, 'Holiday', 'H', Colors.orange, currentStatus),
        const SizedBox(width: 2),
        _buildCompactButton(facultyId, 'Course Completed', 'CC', Colors.teal, currentStatus),
        const SizedBox(width: 2),
        _buildCompactButton(facultyId, 'Not Started', 'NS', Colors.grey, currentStatus),
      ],
    );
  }

  Widget _buildCompactButton(String facultyId, String status, String label, Color color, String currentStatus) {
    final isSelected = currentStatus.toLowerCase() == status.toLowerCase();
    return InkWell(
      onTap: () { 
        setState(() { 
          _attendanceStatus[facultyId] = status; 
        }); 
      }, 
      child: Container(
        width: label == 'OFF' ? 32 : 24,
        height: 26,
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey.shade200, 
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isSelected ? color : Colors.grey.shade400, width: 1),
        ), 
        child: Center(
          child: Text(
            label, 
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade700, 
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: label == 'OFF' ? 9 : 10,
            ),
          ),
        ),
      ),
    );
  }
}
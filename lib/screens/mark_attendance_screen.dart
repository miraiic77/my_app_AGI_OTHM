import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MarkAttendanceScreen extends StatefulWidget {
  const MarkAttendanceScreen({super.key});

  @override
  State<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen> {
  String? _selectedBatchId;
  String? _selectedBatchName;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isSaving = false;
  
  Map<String, String> _attendanceStatus = {};
  List<Map<String, dynamic>> _students = [];

  final List<Map<String, String>> _attendanceStatuses = [
    {'label': 'P', 'value': 'Present', 'full': 'Present'},
    {'label': 'A', 'value': 'Absent', 'full': 'Absent'},
    {'label': 'OFF', 'value': 'Off', 'full': 'Off'},
    {'label': 'H', 'value': 'Holiday', 'full': 'Holiday'},
    {'label': 'CC', 'value': 'Course Completed', 'full': 'Course Completed'},
    {'label': 'NS', 'value': 'Not Started', 'full': 'Not Started'},
  ];

  Future<void> _loadStudents() async {
    if (_selectedBatchId == null) return;
    setState(() => _isLoading = true);
    _attendanceStatus.clear();
    _students.clear();

    try {
      final studentsSnapshot = await FirebaseFirestore.instance
          .collection('students')
          .where('batchId', isEqualTo: _selectedBatchId)
          .orderBy('name')
          .get();

      for (var doc in studentsSnapshot.docs) {
        final data = doc.data();
        _students.add({
          'id': doc.id,
          'name': data['name'] ?? '',
          'rollNumber': data['rollNumber'] ?? '',
          'email': data['email'] ?? '',
        });
        _attendanceStatus[doc.id] = 'Present';
      }

      final dateStr = _formatDate(_selectedDate);
      final existingAttendance = await FirebaseFirestore.instance
          .collection('student_attendance')
          .where('date', isEqualTo: dateStr)
          .where('batchId', isEqualTo: _selectedBatchId)
          .get();

      if (existingAttendance.docs.isNotEmpty) {
        for (var doc in existingAttendance.docs) {
          final data = doc.data();
          final studentId = data['studentId'];
          if (studentId != null) {
            _attendanceStatus[studentId] = data['status'] ?? 'Present';
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('⚠️ Attendance already marked for this date. You can update it.'), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading students: $e')));
    }
    setState(() => _isLoading = false);
  }

 Future<void> _saveAttendance() async {
  if (_students.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No students to mark attendance for')));
    return;
  }

  // Check if attendance already exists
  final dateStr = _formatDate(_selectedDate);
  final existing = await FirebaseFirestore.instance
      .collection('student_attendance')
      .where('date', isEqualTo: dateStr)
      .where('batchId', isEqualTo: _selectedBatchId)
      .get();

  if (existing.docs.isNotEmpty) {
    // Show confirmation dialog for update
    bool? confirm = await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('⚠️ Attendance Already Marked'),
      content: Text('Attendance for ${_students.length} students on ${dateStr} already exists. Do you want to UPDATE it?'),
          actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true), 
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          child: const Text('Update Anyway'),
        ),
      ],
    ));

    if (confirm != true) return; // User cancelled
  } else {
    // First time save confirmation
    bool? confirm = await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Save Attendance'),
      content: Text('Save attendance for ${_students.length} students on ${dateStr}?'),
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

    // Delete existing records if any (for update)
    if (existing.docs.isNotEmpty) {
      for (var doc in existing.docs) await doc.reference.delete();
    }

    final batch = FirebaseFirestore.instance.batch();
    for (var student in _students) {
      final status = _attendanceStatus[student['id']] ?? 'Present';
      final docRef = FirebaseFirestore.instance.collection('student_attendance').doc();
      batch.set(docRef, {
        'date': dateStr,
        'batchId': _selectedBatchId,
        'batchName': _selectedBatchName ?? '',
        'studentId': student['id'],
        'studentName': student['name'],
        'rollNumber': student['rollNumber'],
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
          content: Text(existing.docs.isNotEmpty ? '✅ Attendance updated successfully!' : '✅ Attendance saved successfully!'), 
          backgroundColor: Colors.green,
        ),
      );
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
      for (var student in _students) {
        _attendanceStatus[student['id']] = status; 
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
      if (_selectedBatchId != null) _loadStudents();
    }
  }

  String _formatDate(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  int _countByStatus(String status) => _attendanceStatus.values.where((s) => s.toLowerCase() == status.toLowerCase()).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mark Attendance'), 
        backgroundColor: Colors.purple, 
        foregroundColor: Colors.white
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16), 
            color: Colors.purple.shade50, 
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.purple, size: 32), 
                SizedBox(width: 12), 
                Text('Mark Student Attendance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))
              ]
            )
          ),
          Container(
            padding: const EdgeInsets.all(16), 
            color: Colors.grey.shade100,
            child: Column(
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('batches').orderBy('name').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const CircularProgressIndicator();
                    final batches = snapshot.data!.docs;
                    return DropdownButtonFormField<String>(
                      value: _selectedBatchId,
                      decoration: const InputDecoration(
                        labelText: 'Select Batch *', 
                        border: OutlineInputBorder(), 
                        filled: true, 
                        fillColor: Colors.white
                      ),
                      items: batches.map((batch) {
                        final data = batch.data() as Map<String, dynamic>;
                        return DropdownMenuItem(value: batch.id, child: Text(data['name'] ?? 'Unnamed'));
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedBatchId = value;
                          final batch = batches.firstWhere((b) => b.id == value);
                          _selectedBatchName = (batch.data() as Map<String, dynamic>)['name'];
                        });
                        _loadStudents();
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),
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
              ]
            ),
          ),
          if (_students.isNotEmpty)
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
              : _selectedBatchId == null 
                ? const Center(child: Text('Select a batch to view students', style: TextStyle(color: Colors.grey, fontSize: 16)))
                : _students.isEmpty 
                  ? const Center(child: Text('No students in this batch', style: TextStyle(color: Colors.grey, fontSize: 16)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _students.length,
                      itemBuilder: (context, index) {
                        final student = _students[index];
                        final status = _attendanceStatus[student['id']] ?? 'Present';
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
                                    (student['name'] ?? '?')[0].toUpperCase(), 
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
                                        student['name'] ?? '', 
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold, 
                                          fontSize: 13,
                                        ), 
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Roll: ${student['rollNumber'] ?? 'N/A'}', 
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
                                _buildCompactStatusButtons(student['id'], status),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
          if (_students.isNotEmpty)
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
                    _isSaving ? 'Saving...' : 'Save Attendance (${_students.length} students)', 
                    style: const TextStyle(fontSize: 16)
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple, 
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

  Widget _buildCompactStatusButtons(String studentId, String currentStatus) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildCompactButton(studentId, 'Present', 'P', Colors.green, currentStatus),
        const SizedBox(width: 2),
        _buildCompactButton(studentId, 'Absent', 'A', Colors.red, currentStatus),
        const SizedBox(width: 2),
        _buildCompactButton(studentId, 'Off', 'OFF', Colors.blue, currentStatus),
        const SizedBox(width: 2),
        _buildCompactButton(studentId, 'Holiday', 'H', Colors.orange, currentStatus),
        const SizedBox(width: 2),
        _buildCompactButton(studentId, 'Course Completed', 'CC', Colors.teal, currentStatus),
        const SizedBox(width: 2),
        _buildCompactButton(studentId, 'Not Started', 'NS', Colors.grey, currentStatus),
      ],
    );
  }

  Widget _buildCompactButton(String studentId, String status, String label, Color color, String currentStatus) {
    final isSelected = currentStatus.toLowerCase() == status.toLowerCase();
    return InkWell(
      onTap: () { 
        setState(() { 
          _attendanceStatus[studentId] = status; 
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) { 
      case 'Present': return Colors.green; 
      case 'Absent': return Colors.red; 
      case 'off': return Colors.blue; 
      case 'holiday': return Colors.orange; 
      case 'course completed': return Colors.teal; 
      case 'not started': return Colors.grey; 
      default: return Colors.grey; 
    }
  }
}
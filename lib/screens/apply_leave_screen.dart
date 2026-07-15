import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ApplyLeaveScreen extends StatefulWidget {
  const ApplyLeaveScreen({super.key});

  @override
  State<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends State<ApplyLeaveScreen> {
  final _reasonController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  final _user = FirebaseAuth.instance.currentUser; // ✅ Only declared once

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _isLoading = false;
  
  String _userName = 'Loading...';
  String _userRole = 'user';
  String _userBatchOrSubject = '';
  String _rollNumber = '';

  final String _genericStudentEmail = 'student.portal@app.com';

  @override
  void initState() {
    super.initState();
    _fetchUserDetails();
  }

  Future<void> _fetchUserDetails() async {
    if (_user == null) return;
    
    // Check if this is a student using the generic account
    if (_user?.email == _genericStudentEmail) {
      // Fetch from active_sessions to get the actual student's info
      final sessionDoc = await _firestore
          .collection('active_sessions')
          .doc(_user!.uid)
          .get();
      
      if (sessionDoc.exists && mounted) {
        final sessionData = sessionDoc.data() as Map<String, dynamic>;
        _rollNumber = sessionData['rollNumber'] ?? '';
        
        // Fetch the student details from students collection
        final studentQuery = await _firestore
            .collection('students')
            .where('rollNumber', isEqualTo: _rollNumber)
            .limit(1)
            .get();
        
        if (studentQuery.docs.isNotEmpty) {
          final studentData = studentQuery.docs.first.data();
          setState(() {
            _userName = studentData['name'] ?? 'Unknown Student';
            _userRole = 'Student';
            _userBatchOrSubject = studentData['batch'] ?? studentData['batchId'] ?? '';
          });
        }
      }
    } else {
      // Regular staff/admin login
      final doc = await _firestore.collection('users').doc(_user!.uid).get();
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _userName = data['name'] ?? data['email'] ?? 'Unknown';
          _userRole = data['role'] ?? 'user';
          _userBatchOrSubject = data['batchName'] ?? data['subject'] ?? '';
        });
      }
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) _endDate = _startDate;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  Future<void> _submitLeave() async {
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a reason for leave.')));
      return;
    }

    if (_user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You must be logged in to submit a leave request.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _firestore.collection('leave_requests').add({
        'applicantId': _user!.uid,
        'applicantName': _userName,
        'applicantRole': _userRole,
        'batchOrSubject': _userBatchOrSubject,
        'rollNumber': _rollNumber,
        'startDate': _formatDate(_startDate),
        'endDate': _formatDate(_endDate),
        'reason': _reasonController.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Leave request submitted successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Apply for Leave'), backgroundColor: Colors.teal, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.teal.shade200)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Applying as: $_userName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
                  const SizedBox(height: 4),
                  Text('Role: ${_userRole.toUpperCase()}${_rollNumber.isNotEmpty ? ' | Roll No: $_rollNumber' : ''}${_userBatchOrSubject.isNotEmpty ? ' | Batch: $_userBatchOrSubject' : ''}', style: TextStyle(color: Colors.grey.shade700)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text('Leave Duration', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildDatePickerBox('Start Date', _startDate, () => _pickDate(true))),
                const SizedBox(width: 12),
                Expanded(child: _buildDatePickerBox('End Date', _endDate, () => _pickDate(false))),
              ],
            ),
            const SizedBox(height: 24),

            const Text('Reason for Leave', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'e.g., Medical emergency, Family function...',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _submitLeave,
                icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send),
                label: Text(_isLoading ? 'Submitting...' : 'Submit Leave Request', style: const TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePickerBox(String label, DateTime date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8), color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Text(_formatDate(date), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
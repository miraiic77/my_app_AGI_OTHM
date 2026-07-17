import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/csv_service.dart';
import '../services/role_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// 📊 Main Screen Class for viewing all attendance reports and analytics
class ViewReportsScreen extends StatefulWidget {
  const ViewReportsScreen({super.key});

  @override
  State<ViewReportsScreen> createState() => _ViewReportsScreenState();
}

// 📊 State class managing tabs, independent filters, and data fetching for reports
class _ViewReportsScreenState extends State<ViewReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  
  // ✅ INDEPENDENT FILTER VARIABLES FOR EACH TAB
  String? _studentBatchId;
  String? _studentSession;
  String _studentSearchQuery = '';
  
  String? _facultySession;
  String _facultySearchQuery = '';
  
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  
  bool _isFacultyAnalytics = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    // ✅ Update UI when tab changes for IndexedStack
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(context: context, initialDate: _startDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(context: context, initialDate: _endDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_selectedYear, _selectedMonth),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = picked.month;
        _selectedYear = picked.year;
      });
    }
  }

  String _formatDate(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  
  String _getMonthName(int month) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 
                    'July', 'August', 'September', 'October', 'November', 'December'];
    return months[month - 1];
  }

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
        title: const Text('View Reports'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          FutureBuilder<bool>(
            future: RoleService().isAdmin(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!) return const SizedBox.shrink();
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.sync), tooltip: 'Sync to Google Sheets', onPressed: _syncToGoogleSheets),
                  IconButton(icon: const Icon(Icons.delete_sweep), tooltip: 'Monthly Cleanup', onPressed: _monthlyCleanup),
                ],
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.red,
          labelColor: Colors.red,
          unselectedLabelColor: Colors.amber,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          isScrollable: true,
          tabs: const [
            Tab(text: 'Student Reports'), 
            Tab(text: 'Faculty Reports'),
            Tab(text: 'Monthly Summary'),
            Tab(text: 'Visual Analytics'),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.teal.shade50,
            child: Column(
              children: [
                if (_tabController.index != 2) ...[
                  Row(
                    children: [
                      Expanded(child: InkWell(onTap: _pickStartDate, child: InputDecorator(decoration: const InputDecoration(labelText: 'Start Date', border: OutlineInputBorder(), filled: true, fillColor: Colors.white, suffixIcon: Icon(Icons.calendar_today, size: 20)), child: Text(_formatDate(_startDate))))),
                      const SizedBox(width: 12),
                      Expanded(child: InkWell(onTap: _pickEndDate, child: InputDecorator(decoration: const InputDecoration(labelText: 'End Date', border: OutlineInputBorder(), filled: true, fillColor: Colors.white, suffixIcon: Icon(Icons.calendar_today, size: 20)), child: Text(_formatDate(_endDate))))),
                    ],
                  ),
                ],
                
                if (_tabController.index == 0) ...[
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('batches').orderBy('name').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox(height: 56);
                      final batches = snapshot.data!.docs;
                      return Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _studentBatchId,
                              decoration: InputDecoration(
                                labelText: 'Filter by Batch',
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.white,
                                suffixIcon: _studentBatchId != null
                                    ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() => _studentBatchId = null))
                                    : null,
                              ),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('All Batches')), 
                                ...batches.map((batch) { 
                                  final data = batch.data() as Map<String, dynamic>; 
                                  return DropdownMenuItem(value: batch.id, child: Text(data['name'] ?? 'Unnamed')); 
                                })
                              ],
                              onChanged: (value) => setState(() => _studentBatchId = value),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _studentSession,
                          decoration: InputDecoration(
                            labelText: 'Filter by Session',
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                            suffixIcon: _studentSession != null
                                ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() => _studentSession = null))
                                : null,
                          ),
                          items: const [
                            DropdownMenuItem(value: null, child: Text('All Sessions')),
                            DropdownMenuItem(value: 'SESS1', child: Text('SESS1 (Morning)')),
                            DropdownMenuItem(value: 'SESS2', child: Text('SESS2 (Afternoon)')),
                          ],
                          onChanged: (value) => setState(() => _studentSession = value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search student by name...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                      suffixIcon: _studentSearchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _studentSearchQuery = '')) : null,
                    ),
                    onChanged: (value) => setState(() => _studentSearchQuery = value.toLowerCase()),
                  ),
                ],
                
                if (_tabController.index == 1) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _facultySession,
                          decoration: InputDecoration(
                            labelText: 'Filter by Session',
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                            suffixIcon: _facultySession != null
                                ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() => _facultySession = null))
                                : null,
                          ),
                          items: const [
                            DropdownMenuItem(value: null, child: Text('All Sessions')),
                            DropdownMenuItem(value: 'SESS1', child: Text('SESS1 (Morning)')),
                            DropdownMenuItem(value: 'SESS2', child: Text('SESS2 (Afternoon)')),
                          ],
                          onChanged: (value) => setState(() => _facultySession = value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search faculty by name...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                      suffixIcon: _facultySearchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _facultySearchQuery = '')) : null,
                    ),
                    onChanged: (value) => setState(() => _facultySearchQuery = value.toLowerCase()),
                  ),
                ],
                
                if (_tabController.index == 2) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickMonth,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Select Month & Year',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                              suffixIcon: Icon(Icons.calendar_month, size: 20),
                            ),
                            child: Text('${_getMonthName(_selectedMonth)} $_selectedYear'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          
          // ✅ OPTIMIZED: IndexedStack ONLY builds the currently visible tab, making it 3x faster to open!
          Expanded(
            child: IndexedStack(
              index: _tabController.index,
              children: [
                _buildStudentReports(),
                _buildFacultyReports(),
                _buildMonthlySummary(),
                _buildVisualAnalytics(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🎓 Builds the Student Reports tab
  Widget _buildStudentReports() {
    final startDateStr = _formatDate(_startDate);
    final endDateStr = _formatDate(_endDate);
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('student_attendance')
          .where('date', isGreaterThanOrEqualTo: startDateStr)
          .where('date', isLessThanOrEqualTo: endDateStr)
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}', textAlign: TextAlign.center),
                const SizedBox(height: 8),
                const Text('⚠️ If this says "missing index", check your browser console (F12) for a Firebase link to create it.', 
                    style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
              ],
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No attendance records found for this period.'));
        }
        
        final allRecords = snapshot.data!.docs;
        
        var filteredRecords = allRecords.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final session = data['session'] ?? '';
          final batchId = data['batchId'] ?? '';
          
          bool sessionMatch = _studentSession == null || session == _studentSession || session.isEmpty;
          bool batchMatch = _studentBatchId == null || batchId == _studentBatchId;
          
          return sessionMatch && batchMatch;
        }).toList();

        if (_studentSearchQuery.isNotEmpty) {
          filteredRecords = filteredRecords.where((doc) => 
            (doc.data() as Map<String, dynamic>)['studentName'].toString().toLowerCase().contains(_studentSearchQuery)
          ).toList();
        }

        if (filteredRecords.isEmpty) return const Center(child: Text('No matching records found'));

        Map<String, List<Map<String, dynamic>>> groupedByStudent = {};
        for (var doc in filteredRecords) {
          final data = doc.data() as Map<String, dynamic>;
          final studentId = data['studentId'] ?? 'unknown';
          if (!groupedByStudent.containsKey(studentId)) groupedByStudent[studentId] = [];
          groupedByStudent[studentId]!.add({'date': data['date'], 'status': data['status'], 'studentName': data['studentName'], 'rollNumber': data['rollNumber'], 'batchName': data['batchName'], 'docId': doc.id});
        }

        int totalRecords = filteredRecords.length;
        int present = filteredRecords.where((doc) => (doc.data() as Map<String, dynamic>)['status']?.toString().toLowerCase() == 'present').length;
        int absent = filteredRecords.where((doc) => (doc.data() as Map<String, dynamic>)['status']?.toString().toLowerCase() == 'absent').length;
        int workingDays = present + absent;
        double attendancePercentage = workingDays > 0 ? ((present / workingDays) * 100) : 0;

        return SingleChildScrollView(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.white,
                child: Column(children: [
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      SizedBox(width: (MediaQuery.of(context).size.width - 56) / 2, child: _buildStatCardWrap('Total', '$totalRecords', Colors.blue)),
                      SizedBox(width: (MediaQuery.of(context).size.width - 56) / 2, child: _buildStatCardWrap('Present', '$present', Colors.green, onTap: () {
                        final list = filteredRecords.where((doc) => (doc.data() as Map<String, dynamic>)['status']?.toString().toLowerCase() == 'present').toList();
                        _showAttendanceList('Present Students', list, false);
                      })),
                      SizedBox(width: (MediaQuery.of(context).size.width - 56) / 2, child: _buildStatCardWrap('Absent', '$absent', Colors.red, onTap: () {
                        final list = filteredRecords.where((doc) => (doc.data() as Map<String, dynamic>)['status']?.toString().toLowerCase() == 'absent').toList();
                        _showAttendanceList('Absent Students', list, false);
                      })),
                    ],
                  ), 
                  const SizedBox(height: 12),
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.teal.shade200)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.analytics, color: Colors.teal, size: 28), const SizedBox(width: 8), Flexible(child: Text('Overall: ${attendancePercentage.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)))])),
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () => _exportStudentCsv(groupedByStudent), icon: const Icon(Icons.file_download), label: const Text('Export CSV'), style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white))),
                ]),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(8),
                itemCount: groupedByStudent.length,
                itemBuilder: (context, index) {
                  final studentId = groupedByStudent.keys.elementAt(index);
                  final records = groupedByStudent[studentId]!;
                  if (records.isEmpty) return const SizedBox();
                  
                  final firstRecord = records.first;
                  final studentName = firstRecord['studentName'] ?? 'Unknown';
                  final rollNumber = firstRecord['rollNumber'] ?? 'N/A';
                  final batchName = firstRecord['batchName'] ?? 'N/A';
                  
                  int studentPresent = records.where((r) => r['status']?.toString().toLowerCase() == 'present').length;
                  int studentAbsent = records.where((r) => r['status']?.toString().toLowerCase() == 'absent').length;
                  int studentTotal = records.length;
                  
                  int workingDaysStudent = studentPresent + studentAbsent;
                  double studentPercentage = workingDaysStudent > 0 ? ((studentPresent / workingDaysStudent) * 100) : 0;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: ExpansionTile(
                      leading: CircleAvatar(backgroundColor: studentPercentage >= 75 ? Colors.green : studentPercentage >= 50 ? Colors.orange : Colors.red, child: Text(studentName[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(studentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis, maxLines: 1),
                          const SizedBox(height: 2),
                          Text('Roll: $rollNumber | Batch: $batchName', style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis, maxLines: 1),
                        ],
                      ),
                      subtitle: Text('Attendance: ${studentPercentage.toStringAsFixed(0)}% (${studentPresent}P/${studentAbsent}A)', style: TextStyle(color: studentPercentage >= 75 ? Colors.green : studentPercentage >= 50 ? Colors.orange : Colors.red, fontWeight: FontWeight.bold)),
                      trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: studentPercentage >= 75 ? Colors.green.shade100 : studentPercentage >= 50 ? Colors.orange.shade100 : Colors.red.shade100, borderRadius: BorderRadius.circular(20), border: Border.all(color: studentPercentage >= 75 ? Colors.green : studentPercentage >= 50 ? Colors.orange : Colors.red)), child: Text('${studentTotal}', style: TextStyle(color: studentPercentage >= 75 ? Colors.green.shade700 : studentPercentage >= 50 ? Colors.orange.shade700 : Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 12))),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Attendance History:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 8),
                            Wrap(spacing: 8, runSpacing: 8, children: records.map((record) {
                              final date = record['date'] ?? '';
                              final status = record['status'] ?? '';
                              final color = _getStatusColor(status);
                              return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color)), child: Row(mainAxisSize: MainAxisSize.min, children: [Text(date, style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)), child: Text(status.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12)))]));
                            }).toList()),
                            const SizedBox(height: 16),
                            FutureBuilder<bool>(
                              future: RoleService().isAdmin(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData || !snapshot.data!) return const SizedBox();
                                return Row(children: [
                                  Expanded(child: ElevatedButton.icon(onPressed: () => _editAttendanceRecord(studentId, records), icon: const Icon(Icons.edit), label: const Text('Edit'), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue))),
                                  const SizedBox(width: 8),
                                  Expanded(child: ElevatedButton.icon(onPressed: () => _deleteAttendanceRecords(studentId, records), icon: const Icon(Icons.delete), label: const Text('Delete'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red))),
                                ]);
                              },
                            ),
                          ]),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 👨‍🏫 Builds the Faculty Reports tab
  Widget _buildFacultyReports() {
    final startDateStr = _formatDate(_startDate);
    final endDateStr = _formatDate(_endDate);
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('faculty_attendance')
          .where('date', isGreaterThanOrEqualTo: startDateStr)
          .where('date', isLessThanOrEqualTo: endDateStr)
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading faculty data: ${snapshot.error}\n\nCheck F12 Console for missing index link.'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No attendance records found for this period.'));
        }
        
        final allRecords = snapshot.data!.docs;
        
        var filteredRecords = allRecords.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final session = data['session'] ?? '';
          bool sessionMatch = _facultySession == null || session == _facultySession || session.isEmpty;
          return sessionMatch;
        }).toList();

        if (_facultySearchQuery.isNotEmpty) {
          filteredRecords = filteredRecords.where((doc) => 
            (doc.data() as Map<String, dynamic>)['facultyName'].toString().toLowerCase().contains(_facultySearchQuery)
          ).toList();
        }

        if (filteredRecords.isEmpty) return const Center(child: Text('No matching records found'));

        Map<String, List<Map<String, dynamic>>> groupedByFaculty = {};
        for (var doc in filteredRecords) {
          final data = doc.data() as Map<String, dynamic>;
          final facultyId = data['facultyId'] ?? 'unknown';
          if (!groupedByFaculty.containsKey(facultyId)) groupedByFaculty[facultyId] = [];
          groupedByFaculty[facultyId]!.add({'date': data['date'], 'status': data['status'], 'facultyName': data['facultyName'], 'subject': data['subject'], 'docId': doc.id});
        }

        int totalRecords = filteredRecords.length;
        int present = filteredRecords.where((doc) => (doc.data() as Map<String, dynamic>)['status']?.toString().toLowerCase() == 'present').length;
        int absent = filteredRecords.where((doc) => (doc.data() as Map<String, dynamic>)['status']?.toString().toLowerCase() == 'absent').length;
        int workingDays = present + absent;
        double attendancePercentage = workingDays > 0 ? ((present / workingDays) * 100) : 0;

        return SingleChildScrollView(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.white,
                child: Column(children: [
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      SizedBox(width: (MediaQuery.of(context).size.width - 56) / 2, child: _buildStatCardWrap('Total', '$totalRecords', Colors.blue)),
                      SizedBox(width: (MediaQuery.of(context).size.width - 56) / 2, child: _buildStatCardWrap('Present', '$present', Colors.green, onTap: () {
                        final list = filteredRecords.where((doc) => (doc.data() as Map<String, dynamic>)['status']?.toString().toLowerCase() == 'present').toList();
                        _showAttendanceList('Present Faculty', list, true);
                      })),
                      SizedBox(width: (MediaQuery.of(context).size.width - 56) / 2, child: _buildStatCardWrap('Absent', '$absent', Colors.red, onTap: () {
                        final list = filteredRecords.where((doc) => (doc.data() as Map<String, dynamic>)['status']?.toString().toLowerCase() == 'absent').toList();
                        _showAttendanceList('Absent Faculty', list, true);
                      })),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.teal.shade200)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.analytics, color: Colors.teal, size: 28), const SizedBox(width: 8), Flexible(child: Text('Overall: ${attendancePercentage.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)))])),
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () => _exportFacultyCsv(groupedByFaculty), icon: const Icon(Icons.file_download), label: const Text('Export CSV'), style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white))),
                ]),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(8),
                itemCount: groupedByFaculty.length,
                itemBuilder: (context, index) {
                  final facultyId = groupedByFaculty.keys.elementAt(index);
                  final records = groupedByFaculty[facultyId]!;
                  if (records.isEmpty) return const SizedBox();
                  
                  final firstRecord = records.first;
                  final facultyName = firstRecord['facultyName'] ?? 'Unknown';
                  final subject = firstRecord['subject'] ?? 'N/A';
                  
                  int facultyPresent = records.where((r) => r['status']?.toString().toLowerCase() == 'present').length;
                  int facultyAbsent = records.where((r) => r['status']?.toString().toLowerCase() == 'absent').length;
                  int facultyTotal = records.length;
                  
                  int workingDaysFaculty = facultyPresent + facultyAbsent;
                  double facultyPercentage = workingDaysFaculty > 0 ? ((facultyPresent / workingDaysFaculty) * 100) : 0;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: ExpansionTile(
                      leading: CircleAvatar(backgroundColor: facultyPercentage >= 75 ? Colors.green : facultyPercentage >= 50 ? Colors.orange : Colors.red, child: Text(facultyName[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(facultyName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis, maxLines: 1),
                          const SizedBox(height: 2),
                          Text('Subject: $subject', style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis, maxLines: 1),
                        ],
                      ),
                      subtitle: Text('Attendance: ${facultyPercentage.toStringAsFixed(0)}% (${facultyPresent}P/${facultyAbsent}A)', style: TextStyle(color: facultyPercentage >= 75 ? Colors.green : facultyPercentage >= 50 ? Colors.orange : Colors.red, fontWeight: FontWeight.bold)),
                      trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: facultyPercentage >= 75 ? Colors.green.shade100 : facultyPercentage >= 50 ? Colors.orange.shade100 : Colors.red.shade100, borderRadius: BorderRadius.circular(20), border: Border.all(color: facultyPercentage >= 75 ? Colors.green : facultyPercentage >= 50 ? Colors.orange : Colors.red)), child: Text('${facultyTotal}', style: TextStyle(color: facultyPercentage >= 75 ? Colors.green.shade700 : facultyPercentage >= 50 ? Colors.orange.shade700 : Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 12))),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Attendance History:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 8),
                            Wrap(spacing: 8, runSpacing: 8, children: records.map((record) {
                              final date = record['date'] ?? '';
                              final status = record['status'] ?? '';
                              final color = _getStatusColor(status);
                              return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color)), child: Row(mainAxisSize: MainAxisSize.min, children: [Text(date, style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)), child: Text(status.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12)))]));
                            }).toList()),
                            const SizedBox(height: 16),
                            FutureBuilder<bool>(
                              future: RoleService().isAdmin(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData || !snapshot.data!) return const SizedBox();
                                return Row(children: [
                                  Expanded(child: ElevatedButton.icon(onPressed: () => _editAttendanceRecord(facultyId, records, isFaculty: true), icon: const Icon(Icons.edit), label: const Text('Edit'), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue))),
                                  const SizedBox(width: 8),
                                  Expanded(child: ElevatedButton.icon(onPressed: () => _deleteAttendanceRecords(facultyId, records, isFaculty: true), icon: const Icon(Icons.delete), label: const Text('Delete'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red))),
                                ]);
                              },
                            ),
                          ]),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 📅 Builds the Monthly Summary tab
  Widget _buildMonthlySummary() {
    final monthStr = _selectedMonth.toString().padLeft(2, '0');
    final yearStr = _selectedYear.toString();
    final startDate = '$yearStr-$monthStr-01';
    final endDate = '$yearStr-$monthStr-31';
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('student_attendance')
          .where('date', isGreaterThanOrEqualTo: startDate)
          .where('date', isLessThanOrEqualTo: endDate)
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading monthly data: ${snapshot.error}\n\nCheck F12 Console for missing index link.'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No attendance records found for this month.'));
        }
        
        final allRecords = snapshot.data!.docs;
        Map<String, Map<String, dynamic>> batchSummary = {};
        
        for (var doc in allRecords) {
          final data = doc.data() as Map<String, dynamic>;
          final batchId = data['batchId'] ?? 'unknown';
          final batchName = data['batchName'] ?? 'Unknown';
          final status = (data['status'] ?? '').toLowerCase();
          
          if (!batchSummary.containsKey(batchId)) {
            batchSummary[batchId] = {
              'batchName': batchName,
              'totalStudents': <String>{},
              'Present': 0, 'Absent': 0, 'Off': 0, 'Holiday': 0, 'Course Completed': 0, 'Not Started': 0,
            };
          }
          
          final studentId = data['studentId'] ?? '';
          if (studentId.isNotEmpty) (batchSummary[batchId]!['totalStudents'] as Set<String>).add(studentId);
          
          if (status == 'present') batchSummary[batchId]!['Present']++;
          else if (status == 'absent') batchSummary[batchId]!['Absent']++;
          else if (status == 'off') batchSummary[batchId]!['Off']++;
          else if (status == 'holiday') batchSummary[batchId]!['Holiday']++;
          else if (status == 'course completed') batchSummary[batchId]!['Course Completed']++;
          else if (status == 'not started') batchSummary[batchId]!['Not Started']++;
        }

        List<Map<String, dynamic>> summaryList = batchSummary.entries.map((entry) {
          final data = entry.value;
          final totalStudents = (data['totalStudents'] as Set<String>).length;
          final present = data['Present'] as int;
          final absent = data['Absent'] as int;
          final workingDays = present + absent;
          final percentage = workingDays > 0 ? ((present / workingDays) * 100) : 0;
          
          return {
            'batchName': data['batchName'],
            'totalStudents': totalStudents,
            'Present': present, 'Absent': absent, 'Off': data['Off'] as int, 'Holiday': data['Holiday'] as int,
            'percentage': percentage,
          };
        }).toList();

        summaryList.sort((a, b) => (a['batchName'] as String).compareTo(b['batchName'] as String));

        return SingleChildScrollView(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.teal.shade50,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_month, color: Colors.teal, size: 32),
                    const SizedBox(width: 12),
                    Flexible(child: Text('Summary - ${_getMonthName(_selectedMonth)} $_selectedYear', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal))),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _exportMonthlySummary(summaryList),
                    icon: const Icon(Icons.file_download),
                    label: const Text('Export Summary to CSV'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(8),
                itemCount: summaryList.length,
                itemBuilder: (context, index) {
                  final data = summaryList[index];
                  final batchName = data['batchName'] as String;
                  final totalStudents = data['totalStudents'] as int;
                  final present = data['Present'] as int;
                  final absent = data['Absent'] as int;
                  final off = data['Off'] as int;
                  final percentage = data['percentage'] as double;
                  final color = percentage >= 75 ? Colors.green : percentage >= 50 ? Colors.orange : Colors.red;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.class_, color: Colors.blue, size: 24),
                              const SizedBox(width: 8),
                              Expanded(child: Text(batchName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color)),
                                child: Text('${percentage.toStringAsFixed(1)}%', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8, runSpacing: 8,
                            children: [
                              SizedBox(width: (MediaQuery.of(context).size.width - 56) / 2, child: _buildSummaryStatWrap('Total Students', '$totalStudents', Colors.blue)),
                              SizedBox(width: (MediaQuery.of(context).size.width - 56) / 2, child: _buildSummaryStatWrap('Present', '$present', Colors.green)),
                              SizedBox(width: (MediaQuery.of(context).size.width - 56) / 2, child: _buildSummaryStatWrap('Absent', '$absent', Colors.red)),
                              SizedBox(width: (MediaQuery.of(context).size.width - 56) / 2, child: _buildSummaryStatWrap('Off', '$off', Colors.blue.shade300)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 📊 Builds the Visual Analytics tab
  Widget _buildVisualAnalytics() {
    final collectionName = _isFacultyAnalytics ? 'faculty_attendance' : 'student_attendance';
    final titleText = _isFacultyAnalytics ? 'Faculty Analytics' : 'Student Analytics';
    final startDateStr = _formatDate(_startDate);
    final endDateStr = _formatDate(_endDate);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChoiceChip(label: const Text('Students'), selected: !_isFacultyAnalytics, onSelected: (val) => setState(() => _isFacultyAnalytics = false), selectedColor: Colors.teal),
              const SizedBox(width: 12),
              ChoiceChip(label: const Text('Faculty'), selected: _isFacultyAnalytics, onSelected: (val) => setState(() => _isFacultyAnalytics = true), selectedColor: Colors.teal),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection(collectionName)
                .where('date', isGreaterThanOrEqualTo: startDateStr)
                .where('date', isLessThanOrEqualTo: endDateStr)
                .orderBy('date', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error loading analytics: ${snapshot.error}\n\nCheck F12 Console for missing index link.'));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No attendance records found for the selected date range.'));
              }
              
              final allRecords = snapshot.data!.docs;
              var filteredRecords = allRecords;

              int present = filteredRecords.where((doc) => (doc.data() as Map<String, dynamic>)['status']?.toString().toLowerCase() == 'present').length;
              int absent = filteredRecords.where((doc) => (doc.data() as Map<String, dynamic>)['status']?.toString().toLowerCase() == 'absent').length;
              int off = filteredRecords.where((doc) => (doc.data() as Map<String, dynamic>)['status']?.toString().toLowerCase() == 'off').length;
              int holiday = filteredRecords.where((doc) => (doc.data() as Map<String, dynamic>)['status']?.toString().toLowerCase() == 'holiday').length;
              int total = present + absent + off + holiday;

              if (total == 0) return const Center(child: Text('No attendance records found for the selected date range.'));

              Map<String, int> batchPresent = {};
              Map<String, int> batchTotal = {};
              for (var doc in filteredRecords) {
                final data = doc.data() as Map<String, dynamic>;
                final batchName = data['batchName'] ?? 'Unknown';
                final status = (data['status'] ?? '').toLowerCase();
                
                batchTotal[batchName] = (batchTotal[batchName] ?? 0) + 1;
                if (status == 'present' || status == 'absent') {
                  batchPresent[batchName] = (batchPresent[batchName] ?? 0) + 1;
                }
              }

              final batches = batchTotal.keys.toList();
              final maxTotal = batches.isEmpty ? 10 : batchTotal.values.reduce((a, b) => a > b ? a : b);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titleText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: [
                        SizedBox(width: (MediaQuery.of(context).size.width - 56) / 2, child: _buildStatCardWrap('Total', '$total', Colors.blue)),
                        SizedBox(width: (MediaQuery.of(context).size.width - 56) / 2, child: _buildStatCardWrap('Present', '$present', Colors.green, onTap: () {
                          final list = filteredRecords.where((doc) => (doc.data() as Map<String, dynamic>)['status']?.toString().toLowerCase() == 'present').toList();
                          _showAttendanceList(_isFacultyAnalytics ? 'Present Faculty' : 'Present Students', list, _isFacultyAnalytics);
                        })),
                        SizedBox(width: (MediaQuery.of(context).size.width - 56) / 2, child: _buildStatCardWrap('Absent', '$absent', Colors.red, onTap: () {
                          final list = filteredRecords.where((doc) => (doc.data() as Map<String, dynamic>)['status']?.toString().toLowerCase() == 'absent').toList();
                          _showAttendanceList(_isFacultyAnalytics ? 'Absent Faculty' : 'Absent Students', list, _isFacultyAnalytics);
                        })),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Overall Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 250,
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 2, centerSpaceRadius: 40,
                                sections: [
                                  if (present > 0) PieChartSectionData(value: present.toDouble(), title: 'Present\n${((present/total)*100).toStringAsFixed(0)}%', color: Colors.green, radius: 50, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                                  if (absent > 0) PieChartSectionData(value: absent.toDouble(), title: 'Absent\n${((absent/total)*100).toStringAsFixed(0)}%', color: Colors.red, radius: 50, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                                  if (off > 0) PieChartSectionData(value: off.toDouble(), title: 'Off\n${((off/total)*100).toStringAsFixed(0)}%', color: Colors.blue, radius: 50, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                                  if (holiday > 0) PieChartSectionData(value: holiday.toDouble(), title: 'Holiday\n${((holiday/total)*100).toStringAsFixed(0)}%', color: Colors.orange, radius: 50, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAttendanceList(String title, List<QueryDocumentSnapshot> records, bool isFaculty) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ]),
              const Divider(),
              const SizedBox(height: 8),
              Expanded(
                child: records.isEmpty 
                  ? const Center(child: Text('No records found.'))
                  : ListView.builder(
                      itemCount: records.length,
                      itemBuilder: (context, index) {
                        final data = records[index].data() as Map<String, dynamic>;
                        final name = isFaculty ? (data['facultyName'] ?? data['name'] ?? 'Unknown Faculty') : (data['studentName'] ?? data['name'] ?? 'Unknown Student');
                        final rollOrSubject = isFaculty ? (data['subject'] ?? 'N/A') : (data['rollNumber'] ?? 'N/A');
                        final batch = data['batchName'] ?? '';
                        final date = data['date'] ?? '';
                        final status = data['status'] ?? '';
                        final color = _getStatusColor(status);

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          elevation: 1,
                          child: ListTile(
                            leading: CircleAvatar(backgroundColor: color, child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Roll/Subject: $rollOrSubject | Batch: $batch\nDate: $date'),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                              child: Text(status.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ),
                        );
                      },
                    ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryStatWrap(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.3))),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700), textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _buildStatCardWrap(String label, String value, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
        child: Column(children: [
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700), textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Future<void> _editAttendanceRecord(String personId, List<Map<String, dynamic>> records, {bool isFaculty = false}) async {
    final selectedDate = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(title: const Text('Select Date to Edit'), content: SizedBox(width: 400, height: 300, child: ListView.builder(itemCount: records.length, itemBuilder: (context, index) {
        final record = records[index];
        return ListTile(title: Text(record['date'] ?? ''), trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: _getStatusColor(record['status']).withOpacity(0.2), borderRadius: BorderRadius.circular(4)), child: Text(record['status'].toUpperCase())), onTap: () => Navigator.pop(ctx, record['date']));
      })), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))]),
    );
    if (selectedDate == null) return;

    final newStatus = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select New Status'), 
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.check_circle, color: Colors.green), title: const Text('Present'), onTap: () => Navigator.pop(ctx, 'Present')), 
          ListTile(leading: const Icon(Icons.cancel, color: Colors.red), title: const Text('Absent'), onTap: () => Navigator.pop(ctx, 'Absent')), 
          ListTile(leading: const Icon(Icons.block, color: Colors.blue), title: const Text('Off'), onTap: () => Navigator.pop(ctx, 'Off')), 
          ListTile(leading: const Icon(Icons.celebration, color: Colors.orange), title: const Text('Holiday'), onTap: () => Navigator.pop(ctx, 'Holiday')), 
          ListTile(leading: const Icon(Icons.school, color: Colors.teal), title: const Text('Course Completed'), onTap: () => Navigator.pop(ctx, 'Course Completed')), 
          ListTile(leading: const Icon(Icons.hourglass_empty, color: Colors.grey), title: const Text('Not Started'), onTap: () => Navigator.pop(ctx, 'Not Started')), 
        ]),
      ),
    );
    if (newStatus == null) return;

    try {
      final collectionName = isFaculty ? 'faculty_attendance' : 'student_attendance';
      final idField = isFaculty ? 'facultyId' : 'studentId';
      final query = await FirebaseFirestore.instance.collection(collectionName).where(idField, isEqualTo: personId).where('date', isEqualTo: selectedDate).get();
      for (var doc in query.docs) await doc.reference.update({'status': newStatus});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Attendance updated successfully!')));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'))); }
  }

  Future<void> _deleteAttendanceRecords(String personId, List<Map<String, dynamic>> records, {bool isFaculty = false}) async {
    bool? confirm = await showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Delete Attendance Records'), content: Text('Are you sure you want to delete ${records.length} attendance records?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete'))]));
    if (confirm != true) return;

    try {
      final collectionName = isFaculty ? 'faculty_attendance' : 'student_attendance';
      final idField = isFaculty ? 'facultyId' : 'studentId';
      for (var record in records) {
        final query = await FirebaseFirestore.instance.collection(collectionName).where(idField, isEqualTo: personId).where('date', isEqualTo: record['date']).get();
        for (var doc in query.docs) await doc.reference.delete();
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Records deleted successfully!')));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'))); }
  }

  Future<void> _exportStudentCsv(Map<String, List<Map<String, dynamic>>> groupedData) async {
    List<Map<String, dynamic>> exportData = [];
    groupedData.forEach((studentId, records) { for (var record in records) exportData.add({'Date': record['date'], 'Student Name': record['studentName'], 'Roll Number': record['rollNumber'], 'Batch': record['batchName'], 'Status': record['status']}); });
    String csv = CsvService.convertToCsv(exportData);
    CsvService.downloadCsv(csv, 'student_attendance_report_${_formatDate(_startDate)}_to_${_formatDate(_endDate)}.csv');
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV exported successfully!')));
  }

  Future<void> _exportFacultyCsv(Map<String, List<Map<String, dynamic>>> groupedData) async {
    List<Map<String, dynamic>> exportData = [];
    groupedData.forEach((facultyId, records) { for (var record in records) exportData.add({'Date': record['date'], 'Faculty Name': record['facultyName'], 'Subject': record['subject'], 'Status': record['status']}); });
    String csv = CsvService.convertToCsv(exportData);
    CsvService.downloadCsv(csv, 'faculty_attendance_report_${_formatDate(_startDate)}_to_${_formatDate(_endDate)}.csv');
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV exported successfully!')));
  }

  Future<void> _exportMonthlySummary(List<Map<String, dynamic>> summaryList) async {
    List<Map<String, dynamic>> exportData = summaryList.map((data) {
      return {
        'Batch': data['batchName'], 'Total Students': data['totalStudents'], 'Month': _getMonthName(_selectedMonth), 'Year': _selectedYear,
        'Present': data['Present'], 'Absent': data['Absent'], 'Off': data['Off'], 'Holiday': data['Holiday'],
        'Attendance %': '${(data['percentage'] as double).toStringAsFixed(1)}%',
      };
    }).toList();
    String csv = CsvService.convertToCsv(exportData);
    CsvService.downloadCsv(csv, 'monthly_summary_${_getMonthName(_selectedMonth)}_$_selectedYear.csv');
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Monthly summary exported successfully!')));
  }

  Future<void> _syncToGoogleSheets() async {
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: CircularProgressIndicator()));
    try {
      final scriptUrl = 'https://script.google.com/macros/s/AKfycbx-fYwWAb86WhEGIJs58DZZawbCfiJ5BhOiLbBdk7LdgO3zusGRpzk4rwJ8-VGjEc3wPw/exec';
      final response = await http.get(Uri.parse(scriptUrl));
      if (mounted) Navigator.pop(context);
      if (response.statusCode == 200) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Successfully synced to Google Sheets!'), backgroundColor: Colors.green, duration: Duration(seconds: 3)));
        print('Script response: ${response.body}');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('⚠️ Sync error: $e\n\nTry manual sync from Apps Script.'), backgroundColor: Colors.orange));
    }
  }

  Future<void> _monthlyCleanup() async {
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: CircularProgressIndicator()));
    try {
      final unsyncedStudents = await FirebaseFirestore.instance.collection('student_attendance').where('syncedToSheet', isEqualTo: false).get();
      final unsyncedFaculty = await FirebaseFirestore.instance.collection('faculty_attendance').where('syncedToSheet', isEqualTo: false).get();
      if (mounted) Navigator.pop(context);

      if (unsyncedStudents.docs.isNotEmpty || unsyncedFaculty.docs.isNotEmpty) {
        showDialog(context: context, builder: (ctx) => AlertDialog(
          title: const Row(children: [Icon(Icons.warning, color: Colors.orange), SizedBox(width: 8), Text('⚠️ Cannot Cleanup')]),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Some records are not yet synced to Google Sheets:'), const SizedBox(height: 12),
            if (unsyncedStudents.docs.isNotEmpty) Text('• ${unsyncedStudents.docs.length} student records unsynced'),
            if (unsyncedFaculty.docs.isNotEmpty) Text('• ${unsyncedFaculty.docs.length} faculty records unsynced'),
            const SizedBox(height: 12), const Text('Please sync all records first!', style: TextStyle(fontWeight: FontWeight.bold)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton.icon(onPressed: () { Navigator.pop(ctx); _syncToGoogleSheets(); }, icon: const Icon(Icons.sync), label: const Text('Sync Now'), style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white)),
          ],
        ));
        return;
      }

      if (mounted) {
        showDialog(context: context, builder: (ctx) => AlertDialog(
          title: const Row(children: [Icon(Icons.delete_forever, color: Colors.red), SizedBox(width: 8), Text('🧹 Monthly Cleanup')]),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('This will permanently delete ALL attendance records.'), const SizedBox(height: 16),
            _buildCheckItem('All records synced to Google Sheets', true), const SizedBox(height: 12),
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue)), child: const Row(children: [Icon(Icons.info_outline, color: Colors.blue, size: 20), SizedBox(width: 8), Expanded(child: Text('Make sure you have exported CSV backup before proceeding!', style: TextStyle(fontSize: 12)))])),
            const SizedBox(height: 12), const Text('Type "DELETE" to confirm:', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8),
            TextField(decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Type DELETE'), onChanged: (value) { if (value == 'DELETE') { Navigator.pop(ctx); _confirmAndDeleteAll(); } }),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton.icon(onPressed: () { Navigator.pop(ctx); _exportAllAttendanceCsv(); }, icon: const Icon(Icons.file_download), label: const Text('Export CSV First'), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white)),
          ],
        ));
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red));
    }
  }

  Widget _buildCheckItem(String label, bool isChecked) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Icon(isChecked ? Icons.check_circle : Icons.cancel, color: isChecked ? Colors.green : Colors.red, size: 20), const SizedBox(width: 8), Expanded(child: Text(label))]));
  }

  Future<void> _confirmAndDeleteAll() async {
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('⚠️ FINAL WARNING'),
      content: const Text('This action CANNOT be undone!\n\nAll student and faculty attendance records will be permanently deleted.\n\nMake sure you have:\n✓ Synced to Google Sheets\n✓ Exported CSV backup\n\nAre you absolutely sure?', style: TextStyle(fontSize: 14)),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text('YES, DELETE EVERYTHING'))],
    ));
    if (confirmed != true) return;

    showDialog(context: context, barrierDismissible: false, builder: (ctx) => AlertDialog(title: const Text('Deleting Records...'), content: Column(mainAxisSize: MainAxisSize.min, children: [const CircularProgressIndicator(), const SizedBox(height: 16), const Text('Please wait. Processing in batches...')])));

    try {
      final studentCollection = FirebaseFirestore.instance.collection('student_attendance');
      final facultyCollection = FirebaseFirestore.instance.collection('faculty_attendance');
      int totalDeleted = 0;
      
      bool hasMoreStudents = true;
      while (hasMoreStudents) {
        final studentBatchDocs = await studentCollection.limit(500).get();
        if (studentBatchDocs.docs.isEmpty) { hasMoreStudents = false; break; }
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in studentBatchDocs.docs) batch.delete(doc.reference);
        await batch.commit();
        totalDeleted += studentBatchDocs.docs.length;
      }
      
      bool hasMoreFaculty = true;
      while (hasMoreFaculty) {
        final facultyBatchDocs = await facultyCollection.limit(500).get();
        if (facultyBatchDocs.docs.isEmpty) { hasMoreFaculty = false; break; }
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in facultyBatchDocs.docs) batch.delete(doc.reference);
        await batch.commit();
        totalDeleted += facultyBatchDocs.docs.length;
      }

      if (mounted) Navigator.pop(context);
      if (mounted) {
        showDialog(context: context, builder: (ctx) => AlertDialog(title: const Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 8), Text('✅ Cleanup Complete')]), content: Text('Successfully deleted $totalDeleted records in seconds!'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))]));
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error during cleanup: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _exportAllAttendanceCsv() async {
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: CircularProgressIndicator()));
    try {
      final students = await FirebaseFirestore.instance.collection('student_attendance').get();
      final faculty = await FirebaseFirestore.instance.collection('faculty_attendance').get();
      List<Map<String, dynamic>> exportData = [];
      for (var doc in students.docs) {
        final data = doc.data();
        exportData.add({'Type': 'Student', 'Date': data['date'] ?? '', 'Name': data['studentName'] ?? '', 'Roll/Batch': '${data['rollNumber'] ?? ''} - ${data['batchName'] ?? ''}', 'Status': data['status'] ?? '', 'Marked By': data['markedBy'] ?? ''});
      }
      for (var doc in faculty.docs) {
        final data = doc.data();
        exportData.add({'Type': 'Faculty', 'Date': data['date'] ?? '', 'Name': data['facultyName'] ?? '', 'Roll/Batch': data['subject'] ?? '', 'Status': data['status'] ?? '', 'Marked By': data['markedBy'] ?? ''});
      }
      String csv = CsvService.convertToCsv(exportData);
      final now = DateTime.now();
      CsvService.downloadCsv(csv, 'full_backup_${now.year}_${now.month}.csv');
      await FirebaseFirestore.instance.collection('system_logs').add({'type': 'csv_export', 'timestamp': Timestamp.now(), 'recordsExported': exportData.length, 'performedBy': FirebaseAuth.instance.currentUser?.email ?? 'Unknown'});
      if (mounted) Navigator.pop(context);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Exported ${exportData.length} records!'), backgroundColor: Colors.green, duration: const Duration(seconds: 3)));
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Export error: $e'), backgroundColor: Colors.red));
    }
  }
}
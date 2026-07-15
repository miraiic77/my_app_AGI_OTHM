import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import '../services/csv_service.dart';
import '../services/role_service.dart';

class StudentManagementScreen extends StatefulWidget {
  const StudentManagementScreen({super.key});

  @override
  State<StudentManagementScreen> createState() => _StudentManagementScreenState();
}

class _StudentManagementScreenState extends State<StudentManagementScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _rollController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String? _selectedBatchId;
  String _searchQuery = '';
  
  // ✅ NEW: Batch filter for viewing students
  String? _selectedFilterBatchId; // null = All Batches

  @override
  void dispose() {
    _nameController.dispose();
    _rollController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _clearForm() {
    _nameController.clear();
    _rollController.clear();
    _emailController.clear();
    _phoneController.clear();
    _selectedBatchId = null;
  }

  Future<void> _addStudent() async {
    if (_nameController.text.trim().isEmpty || _selectedBatchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter name and select batch')));
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('students').add({
        'name': _nameController.text.trim(),
        'rollNumber': _rollController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'batchId': _selectedBatchId,
        'enrollmentDate': Timestamp.now(),
      });
      await FirebaseFirestore.instance.collection('batches').doc(_selectedBatchId).update({'studentCount': FieldValue.increment(1)});
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Student added successfully!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _editStudent(String studentId, Map<String, dynamic> data) async {
    _nameController.text = data['name'] ?? '';
    _rollController.text = data['rollNumber'] ?? '';
    _emailController.text = data['email'] ?? '';
    _phoneController.text = data['phone'] ?? '';
    _selectedBatchId = data['batchId'];

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Student'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: _rollController, decoration: const InputDecoration(labelText: 'Roll Number')),
              TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email')),
              TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone')),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('batches').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const CircularProgressIndicator();
                  return DropdownButtonFormField<String>(
                    value: _selectedBatchId,
                    decoration: const InputDecoration(labelText: 'Batch'),
                    items: snapshot.data!.docs.map((batch) {
                      final b = batch.data() as Map<String, dynamic>;
                      return DropdownMenuItem(value: batch.id, child: Text(b['name'] ?? 'Unnamed'));
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedBatchId = value),
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance.collection('students').doc(studentId).update({
                  'name': _nameController.text.trim(),
                  'rollNumber': _rollController.text.trim(),
                  'email': _emailController.text.trim(),
                  'phone': _phoneController.text.trim(),
                  'batchId': _selectedBatchId,
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Student updated!')));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteStudent(String studentId, String? batchId) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Student'),
        content: const Text('Are you sure you want to delete this student?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('students').doc(studentId).delete();
        if (batchId != null) {
          await FirebaseFirestore.instance.collection('batches').doc(batchId).update({'studentCount': FieldValue.increment(-1)});
        }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Student deleted!')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _exportStudents() async {
    try {
      final students = await FirebaseFirestore.instance.collection('students').get();
      final batches = await FirebaseFirestore.instance.collection('batches').get();
      Map<String, String> batchNames = {};
      for (var batch in batches.docs) {
        batchNames[batch.id] = batch.data()['name'] ?? 'Unknown';
      }

      List<Map<String, dynamic>> data = [];
      for (var student in students.docs) {
        final s = student.data();
        data.add({
          'Name': s['name'] ?? '',
          'Roll Number': s['rollNumber'] ?? '',
          'Email': s['email'] ?? '',
          'Phone': s['phone'] ?? '',
          'Batch': batchNames[s['batchId']] ?? 'Unknown',
        });
      }
      String csv = CsvService.convertToCsv(data);
      CsvService.downloadCsv(csv, 'students_export.csv');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Students exported!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _importStudents() async {
    final format = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Format'),
        content: const Text('Choose file format to import'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'csv'), child: const Text('CSV')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'excel'), child: const Text('Excel')),
        ],
      ),
    );
    if (format == null) return;

    List<Map<String, dynamic>> students = [];
    try {
      if (format == 'csv') {
        String? csvData = await CsvService.pickCsvFile();
        if (csvData == null) return;
        students = CsvService.parseCsv(csvData);
      } else {
        PlatformFile? file = await CsvService.pickExcelFile();
        if (file == null) return;
        students = CsvService.parseExcel(file);
      }

            final batchesSnapshot = await FirebaseFirestore.instance.collection('batches').get();
      Map<String, String> batchNameToId = {};
      for (var batch in batchesSnapshot.docs) {
        batchNameToId[batch.data()['name']?.toString().toLowerCase() ?? ''] = batch.id;
      }

      int count = 0; // This only counts successful imports for the success message
      
      for (var student in students) {
        String name = student['Name'] ?? student['name'] ?? '';
        String rollNumber = student['Roll Number'] ?? student['rollNumber'] ?? '';
        String email = student['Email'] ?? student['email'] ?? '';
        String phone = student['Phone'] ?? student['phone'] ?? '';
        String batchName = student['Batch'] ?? student['batch'] ?? '';
        
        if (name.toString().isNotEmpty) {
          String? batchId;
          if (batchName.toString().isNotEmpty) {
            batchId = batchNameToId[batchName.toString().toLowerCase()];
          }

          if (batchId != null) {
            await FirebaseFirestore.instance.collection('students').add({
              'name': name,
              'rollNumber': rollNumber,
              'email': email,
              'phone': phone,
              'batchId': batchId,
              'enrollmentDate': Timestamp.now(),
            });
            
            // This updates the batch's studentCount field in Firestore
            await FirebaseFirestore.instance.collection('batches').doc(batchId).update({
              'studentCount': FieldValue.increment(1)
            });
            
            count++;
          }
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Imported $count students from ${format.toUpperCase()}!'))
        );
      }
      setState(() {});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _showStudentDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Student'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: _rollController, decoration: const InputDecoration(labelText: 'Roll Number')),
              TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email')),
              TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone')),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('batches').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const CircularProgressIndicator();
                  return DropdownButtonFormField<String>(
                    value: _selectedBatchId,
                    decoration: const InputDecoration(labelText: 'Batch'),
                    items: snapshot.data!.docs.map((batch) {
                      final b = batch.data() as Map<String, dynamic>;
                      return DropdownMenuItem(value: batch.id, child: Text(b['name'] ?? 'Unnamed'));
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedBatchId = value),
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: _addStudent, child: const Text('Add')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Management'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.file_download), onPressed: _exportStudents),
          IconButton(icon: const Icon(Icons.file_upload), tooltip: 'Import CSV or Excel', onPressed: _importStudents),
        ],
      ),
      body: Column(
        children: [
          // ✅ NEW: Header with Add Student button
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.green.shade50,
            child: Row(
              children: [
                const Icon(Icons.people, color: Colors.green, size: 32),
                const SizedBox(width: 12),
                const Text('Manage Students', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () { _clearForm(); _showStudentDialog(); },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Student'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                ),
              ],
            ),
          ),
          
          // ✅ NEW: Batch Filter Dropdown
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('batches').orderBy('name').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox(height: 64, child: Center(child: CircularProgressIndicator()));
                final batches = snapshot.data!.docs;
                return Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedFilterBatchId,
                        decoration: InputDecoration(
                          labelText: 'Filter by Batch',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: const Icon(Icons.filter_list, color: Colors.green),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('📋 All Batches')),
                          ...batches.map((batch) {
                            final data = batch.data() as Map<String, dynamic>;
                            final count = data['studentCount'] ?? 0;
                            return DropdownMenuItem(
                              value: batch.id,
                              child: Text('${data['name'] ?? 'Unnamed'} ($count students)'),
                            );
                          }),
                        ],
                        onChanged: (value) => setState(() => _selectedFilterBatchId = value),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name, roll, email...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
                suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _searchQuery = '')) : null,
              ),
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),
          
          // Student List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('students').orderBy('name').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final students = snapshot.data!.docs;
                
                // ✅ NEW: Apply both batch filter AND search filter
                final filtered = students.where((s) {
                  final data = s.data() as Map<String, dynamic>;
                  
                  // Batch filter
                  if (_selectedFilterBatchId != null && data['batchId'] != _selectedFilterBatchId) {
                    return false;
                  }
                  
                  // Search filter
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final roll = (data['rollNumber'] ?? '').toString().toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) || roll.contains(_searchQuery) || email.contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty 
                              ? (_selectedFilterBatchId != null ? 'No students in this batch' : 'No students found.')
                              : 'No match found.',
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final student = filtered[index];
                    final data = student.data() as Map<String, dynamic>;

                    return Card(
  margin: const EdgeInsets.only(bottom: 8),
  child: Padding(
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: Colors.green.shade100,
          child: Text((data['name'] ?? '?')[0].toUpperCase(), style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 12),
        // ✅ FIXED: Use Expanded and Column for mobile-friendly layout
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data['name'] ?? 'Unnamed',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 4),
              Text(
                'Roll: ${data['rollNumber'] ?? 'N/A'}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 2),
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('batches').doc(data['batchId']).get(),
                builder: (context, batchSnapshot) {
                  String batchName = '...';
                  if (batchSnapshot.hasData && batchSnapshot.data!.exists) {
                    batchName = batchSnapshot.data!['name'] ?? 'N/A';
                  }
                  return Text(
                    'Batch: $batchName',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  );
                },
              ),
              const SizedBox(height: 2),
              Text(
                'Email: ${data['email'] ?? 'N/A'}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
        // ✅ FIXED: PopupMenuButton stays on the right
        FutureBuilder<bool>(
          future: RoleService().isAdmin(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!) {
              return const SizedBox();
            }
            return PopupMenuButton<String>(
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 8), Text('Edit')])),
                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 20, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
              ],
              onSelected: (value) {
                if (value == 'edit') _editStudent(student.id, data);
                else if (value == 'delete') _deleteStudent(student.id, data['batchId']);
              },
            );
          },
        ),
      ],
    ),
  ),
);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
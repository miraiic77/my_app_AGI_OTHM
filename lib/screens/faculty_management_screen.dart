import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import '../services/csv_service.dart';
import '../services/role_service.dart';

class FacultyManagementScreen extends StatefulWidget {
  const FacultyManagementScreen({super.key});

  @override
  State<FacultyManagementScreen> createState() => _FacultyManagementScreenState();
}

class _FacultyManagementScreenState extends State<FacultyManagementScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  void _clearForm() {
    _nameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _subjectController.clear();
  }

  Future<void> _addFaculty() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter faculty name')));
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('faculties').add({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'subject': _subjectController.text.trim(),
        'createdAt': Timestamp.now(),
      });
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Faculty added successfully!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _editFaculty(String facultyId, Map<String, dynamic> data) async {
    _nameController.text = data['name'] ?? '';
    _emailController.text = data['email'] ?? '';
    _phoneController.text = data['phone'] ?? '';
    _subjectController.text = data['subject'] ?? '';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Faculty'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email')),
              TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone')),
              TextField(controller: _subjectController, decoration: const InputDecoration(labelText: 'Subject')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance.collection('faculties').doc(facultyId).update({
                  'name': _nameController.text.trim(),
                  'email': _emailController.text.trim(),
                  'phone': _phoneController.text.trim(),
                  'subject': _subjectController.text.trim(),
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Faculty updated!')));
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

  Future<void> _deleteFaculty(String facultyId) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Faculty'),
        content: const Text('Are you sure you want to delete this faculty?'),
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
        await FirebaseFirestore.instance.collection('faculties').doc(facultyId).delete();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Faculty deleted!')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _exportFaculties() async {
    try {
      final faculties = await FirebaseFirestore.instance.collection('faculties').get();
      List<Map<String, dynamic>> data = [];
      for (var faculty in faculties.docs) {
        final f = faculty.data();
        data.add({
          'Name': f['name'] ?? '',
          'Email': f['email'] ?? '',
          'Phone': f['phone'] ?? '',
          'Subject': f['subject'] ?? '',
        });
      }
      String csv = CsvService.convertToCsv(data);
      CsvService.downloadCsv(csv, 'faculties_export.csv');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Faculties exported!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _importFaculties() async {
    // Simplified - just show message
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Import feature coming soon')));
  }

  Future<void> _showFacultyDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Faculty'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email')),
              TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone')),
              TextField(controller: _subjectController, decoration: const InputDecoration(labelText: 'Subject')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: _addFaculty, child: const Text('Add')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Faculty Management'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.file_download), onPressed: _exportFaculties),
          IconButton(icon: const Icon(Icons.file_upload), tooltip: 'Import CSV or Excel', onPressed: _importFaculties),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.orange.shade50,
            child: Row(
              children: [
                const Icon(Icons.school, color: Colors.orange, size: 32),
                const SizedBox(width: 12),
                const Text('Manage Faculty', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () { _clearForm(); _showFacultyDialog(); },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Faculty'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name, email, subject...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _searchQuery = '')) : null,
              ),
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('faculties').orderBy('name').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final faculties = snapshot.data!.docs;
                
                final filtered = faculties.where((f) {
                  final data = f.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final subject = (data['subject'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) || subject.contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) return Center(child: Text(_searchQuery.isEmpty ? 'No faculty found.' : 'No match found.'));

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final faculty = filtered[index];
                    final data = faculty.data() as Map<String, dynamic>;
                    
                    return Card(
  margin: const EdgeInsets.only(bottom: 8),
  child: Padding(
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: Colors.orange.shade100,
          child: Text((data['name'] ?? '?')[0].toUpperCase(), style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.bold)),
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
                'Email: ${data['email'] ?? 'N/A'}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 2),
              Text(
                'Phone: ${data['phone'] ?? 'N/A'}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 2),
              Text(
                'Subject: ${data['subject'] ?? 'N/A'}',
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
                if (value == 'edit') _editFaculty(faculty.id, data);
                else if (value == 'delete') _deleteFaculty(faculty.id);
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
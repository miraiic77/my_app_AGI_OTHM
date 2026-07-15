import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/csv_service.dart';
import '../services/role_service.dart';

class BatchManagementScreen extends StatefulWidget {
  const BatchManagementScreen({super.key});

  @override
  State<BatchManagementScreen> createState() => _BatchManagementScreenState();
}

class _BatchManagementScreenState extends State<BatchManagementScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _facultyIdController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _nameController.dispose();
    _facultyIdController.dispose();
    super.dispose();
  }

  void _clearForm() {
    _nameController.clear();
    _facultyIdController.clear();
  }

  Future<void> _addBatch() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter batch name')));
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('batches').add({
        'name': _nameController.text.trim(),
        'facultyId': _facultyIdController.text.trim(),
        'studentCount': 0,
        'createdAt': Timestamp.now(),
      });
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Batch added successfully!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _editBatch(String batchId, Map<String, dynamic> data) async {
    _nameController.text = data['name'] ?? '';
    _facultyIdController.text = data['facultyId'] ?? '';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Batch'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Batch Name')),
            TextField(controller: _facultyIdController, decoration: const InputDecoration(labelText: 'Faculty ID')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance.collection('batches').doc(batchId).update({
                  'name': _nameController.text.trim(),
                  'facultyId': _facultyIdController.text.trim(),
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Batch updated!')));
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

  Future<void> _deleteBatch(String batchId) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Batch'),
        content: const Text('Are you sure you want to delete this batch?'),
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
        await FirebaseFirestore.instance.collection('batches').doc(batchId).delete();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Batch deleted!')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _syncStudentCounts() async {
    try {
      final batches = await FirebaseFirestore.instance.collection('batches').get();
      for (var batch in batches.docs) {
        final students = await FirebaseFirestore.instance
            .collection('students')
            .where('batchId', isEqualTo: batch.id)
            .get();
        await batch.reference.update({'studentCount': students.docs.length});
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Student counts synced!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _exportBatches() async {
    try {
      final batches = await FirebaseFirestore.instance.collection('batches').get();
      List<Map<String, dynamic>> data = [];
      for (var batch in batches.docs) {
        final b = batch.data();
        data.add({
          'Name': b['name'] ?? '',
          'Faculty ID': b['facultyId'] ?? '',
          'Student Count': b['studentCount'] ?? 0,
        });
      }
      String csv = CsvService.convertToCsv(data);
      CsvService.downloadCsv(csv, 'batches_export.csv');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Batches exported!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _importBatches() async {
    // Simplified import - just show message
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Import feature coming soon')));
  }

  Future<void> _showAddBatchDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Batch'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Batch Name')),
            TextField(controller: _facultyIdController, decoration: const InputDecoration(labelText: 'Faculty ID')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: _addBatch, child: const Text('Add')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch Management'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.sync), tooltip: 'Sync Student Counts', onPressed: _syncStudentCounts),
          IconButton(icon: const Icon(Icons.file_download), onPressed: _exportBatches),
          IconButton(icon: const Icon(Icons.file_upload), tooltip: 'Import CSV or Excel', onPressed: _importBatches),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                const Icon(Icons.class_, color: Colors.blue, size: 32),
                const SizedBox(width: 12),
                const Text('Manage Batches', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () { _clearForm(); _showAddBatchDialog(); },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Batch'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance.collection('batches').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final batches = snapshot.data!.docs;
                if (batches.isEmpty) return const Center(child: Text('No batches found.'));
                
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: batches.length,
                  itemBuilder: (context, index) {
                    final batch = batches[index];
                    final data = batch.data() as Map<String, dynamic>;
                    
                    return Card(
  margin: const EdgeInsets.only(bottom: 8),
  child: Padding(
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.class_, color: Colors.blue),
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
                'Faculty: ${data['facultyId'] ?? 'N/A'}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 2),
              Text(
                'Students: ${data['studentCount'] ?? 0}',
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
                if (value == 'edit') _editBatch(batch.id, data);
                else if (value == 'delete') _deleteBatch(batch.id);
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
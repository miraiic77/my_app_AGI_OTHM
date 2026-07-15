import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ManageLeavesScreen extends StatelessWidget {
  const ManageLeavesScreen({super.key});

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved': return Colors.green;
      case 'rejected': return Colors.red;
      default: return Colors.orange;
    }
  }

  Future<void> _updateLeaveStatus(String docId, String status, BuildContext context) async {
    try {
      await FirebaseFirestore.instance.collection('leave_requests').doc(docId).update({
        'status': status,
        'reviewedBy': FirebaseAuth.instance.currentUser!.uid,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Leave $status successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Leave Requests'), backgroundColor: Colors.teal, foregroundColor: Colors.white),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('leave_requests')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No leave requests found.'));
          }

          final leaves = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: leaves.length,
            itemBuilder: (context, index) {
              final doc = leaves[index];
              final data = doc.data() as Map<String, dynamic>;
              final status = data['status'] ?? 'pending';
              final statusColor = _getStatusColor(status);

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.teal.shade100,
                            child: Text(data['applicantName'][0].toUpperCase(), style: TextStyle(color: Colors.teal.shade900, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(data['applicantName'] ?? 'Unknown', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                Text('${data['applicantRole'] ?? 'user'} | ${data['batchOrSubject'] ?? ''}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: statusColor)),
                            child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Text('Duration: ${data['startDate']} to ${data['endDate']}', style: const TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Text('Reason: ${data['reason']}', style: TextStyle(color: Colors.grey.shade700)),
                      
                      if (status == 'pending') ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _updateLeaveStatus(doc.id, 'approved', context),
                                icon: const Icon(Icons.check),
                                label: const Text('Approve'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _updateLeaveStatus(doc.id, 'rejected', context),
                                icon: const Icon(Icons.close),
                                label: const Text('Reject'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
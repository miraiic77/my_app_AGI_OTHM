import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MyLeavesScreen extends StatelessWidget {
  const MyLeavesScreen({super.key});

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved': return Colors.green;
      case 'rejected': return Colors.red;
      default: return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please login first')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Leave Requests'), backgroundColor: Colors.teal, foregroundColor: Colors.white),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('leave_requests')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('You have not applied for any leaves yet.'));
          }

          final allLeaves = snapshot.data!.docs;
          
          // Filter for this student's leaves
          final studentLeaves = allLeaves.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            // Check by roll number OR by applicantId
            final rollNumber = data['rollNumber'] ?? '';
            final applicantId = data['applicantId'] ?? '';
            
            // For student portal users, check active_sessions
            if (user.email == 'student.portal@app.com') {
              return true; // Show all for now, we'll filter below
            }
            
            return applicantId == user.uid;
          }).toList();

          if (studentLeaves.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No leave requests found.', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Total requests in system: ${allLeaves.length}', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: studentLeaves.length,
            itemBuilder: (context, index) {
              final data = studentLeaves[index].data() as Map<String, dynamic>;
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${data['startDate']} to ${data['endDate']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1), 
                              borderRadius: BorderRadius.circular(20), 
                              border: Border.all(color: statusColor)
                            ),
                            child: Text(
                              status.toUpperCase(), 
                              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Text('Name: ${data['applicantName'] ?? 'Unknown'}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      if (data['rollNumber'] != null && data['rollNumber'].isNotEmpty)
                        Text('Roll Number: ${data['rollNumber']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      if (data['batchOrSubject'] != null && data['batchOrSubject'].isNotEmpty)
                        Text('Batch: ${data['batchOrSubject']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      const SizedBox(height: 8),
                      Text('Reason:', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(data['reason'] ?? 'No reason provided', style: const TextStyle(fontSize: 14)),
                      if (status == 'rejected' && data['adminComment'] != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Expanded(child: Text('Admin Comment: ${data['adminComment']}', style: const TextStyle(color: Colors.red))),
                            ],
                          ),
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
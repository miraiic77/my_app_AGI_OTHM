import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final CollectionReference _usersCollection = FirebaseFirestore.instance.collection('users');
  final String _currentAdminUid = FirebaseAuth.instance.currentUser!.uid;

  // Function to update user role in Firestore
  Future<void> _updateUserRole(String uid, String newRole) async {
    try {
      await _usersCollection.doc(uid).update({'role': newRole});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Role updated to $newRole successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating role: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- 🔓 NEW: FUNCTION TO UNBLOCK A USER ---
  Future<void> _unblockUser(String email) async {
    try {
      await FirebaseFirestore.instance
          .collection('login_attempts')
          .doc(email.trim().toLowerCase())
          .set({'attempts': 0, 'blocked': false}, SetOptions(merge: true));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$email unblocked successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error unblocking user: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  // -------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel - Manage Users'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _usersCollection.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No users found.'));

          final users = List<QueryDocumentSnapshot>.from(snapshot.data!.docs);
          users.sort((a, b) {
            final emailA = (a.data() as Map<String, dynamic>)['email'] ?? '';
            final emailB = (b.data() as Map<String, dynamic>)['email'] ?? '';
            return emailA.toString().compareTo(emailB.toString());
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final userData = users[index].data() as Map<String, dynamic>;
              final uid = users[index].id;
              final email = userData['email'] ?? 'No Email';
              final role = userData['role'] ?? 'viewer';
              final isCurrentUser = uid == _currentAdminUid;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isCurrentUser ? BorderSide(color: Colors.blue.shade200, width: 2) : BorderSide.none,
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: isCurrentUser ? Colors.green.shade100 : Colors.blue.shade100,
                    child: Text(
                      email.isNotEmpty ? email[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: isCurrentUser ? Colors.green.shade900 : Colors.blue.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(email, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isCurrentUser) 
                        const Padding(
                          padding: EdgeInsets.only(top: 4.0),
                          child: Text('You (Current Admin)', style: TextStyle(color: Colors.green, fontSize: 12, fontStyle: FontStyle.italic)),
                        ),
                      Text('UID: $uid', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  // --- 🔓 UPDATED TRAILING SECTION (Role Dropdown + Unblock Button) ---
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 120,
                        child: DropdownButton<String>(
                          value: role,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(value: 'admin', child: Text('Admin')),
                            DropdownMenuItem(value: 'viewer', child: Text('Viewer')),
                            DropdownMenuItem(value: 'user', child: Text('User')),
                          ],
                          onChanged: isCurrentUser ? null : (newRole) {
                            if (newRole != null && newRole != role) {
                              _updateUserRole(uid, newRole);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Real-time Unblock Button (Only shows if user is blocked)
                          StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('login_attempts')
                            .doc(email.trim().toLowerCase())
                            .snapshots(),
                        builder: (ctx, snap) {
                          bool isBlocked = false;
                          if (snap.hasData && snap.data!.exists) {
                            // ✅ FIX: Explicitly cast the data to a Map
                            final data = snap.data!.data() as Map<String, dynamic>?;
                            isBlocked = data?['blocked'] ?? false;
                          }
                          
                          // If not blocked, show nothing
                          if (!isBlocked) return const SizedBox.shrink();
                          
                          // If blocked, show the red unlock button
                          return IconButton(
                            icon: const Icon(Icons.lock_open, color: Colors.red, size: 28),
                            tooltip: 'Unblock User',
                            onPressed: () => _unblockUser(email),
                          );
                        },
                      ),
                    ],
                  ),
                  // -------------------------------------------------------------------
                ),
              );
            },
          );
        },
      ),
    );
  }
}
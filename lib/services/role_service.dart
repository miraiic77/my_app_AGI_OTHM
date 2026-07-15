import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RoleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Check if current user is admin
  Future<bool> isAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return doc.data()?['role'] == 'admin';
      }
    } catch (e) {
      print('Error checking admin role: $e');
    }
    return false;
  }

  // ✅ NEW: Check if current user is viewer
  Future<bool> isViewer() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return doc.data()?['role'] == 'viewer';
      }
    } catch (e) {
      print('Error checking viewer role: $e');
    }
    return false;
  }

  // ✅ NEW: Check if user can edit (only admin can edit)
  Future<bool> canEdit() async {
    return await isAdmin();
  }
    // ✅ NEW: Check if user is Admin OR Faculty
  Future<bool> canManageAttendance() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!doc.exists) return false;

      final role = doc.data()?['role'] as String?;
      // Return true if role is admin OR faculty
      return role == 'admin' || role == 'faculty';
    } catch (e) {
      print('Error checking attendance role: $e');
      return false;
    }
  }

  // ✅ NEW: Check if user can view reports (both admin and viewer can view)
  Future<bool> canViewReports() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final role = doc.data()?['role'];
        return role == 'admin' || role == 'viewer';
      }
    } catch (e) {
      print('Error checking view permission: $e');
    }
    return false;
  }

  // Get current user's role
  Future<String?> getUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return doc.data()?['role'];
      }
    } catch (e) {
      print('Error getting user role: $e');
    }
    return null;
  }

  // ✅ NEW: Clear cached role data (used during logout)
  void clearRole() {
    // This method is called during logout to clear any cached role information
    // Currently, roles are fetched fresh from Firestore each time, so this is a placeholder
    print('Role cache cleared');
  }
}
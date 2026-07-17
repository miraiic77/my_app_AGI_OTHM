import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'batch_management_screen.dart';
import 'student_management_screen.dart';
import 'faculty_management_screen.dart';
import 'mark_attendance_screen.dart';
import 'faculty_attendance_screen.dart';
import 'view_reports_screen.dart';
import '../services/role_service.dart';
import 'admin_panel_screen.dart';
import 'apply_leave_screen.dart';
import 'my_leaves_screen.dart';
import 'manage_leaves_screen.dart';
import '../widgets/branding_footer.dart';
import 'management_dashboard_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final crossAxisCount = isMobile ? 2 : 3;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Attendance Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue.shade700,
        elevation: 2,
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: user == null ? const Stream.empty() : FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                if (data['role'] == 'admin') {
                  return IconButton(
                    icon: const Icon(Icons.admin_panel_settings, size: 22),
                    tooltip: 'Admin Panel',
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminPanelScreen()));
                    },
                  );
                }
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 22),
            onPressed: () async { await FirebaseAuth.instance.signOut(); },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: user == null ? const Stream.empty() : FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, roleSnapshot) {
          // 1. GET USER ROLE
          String role = 'user'; // default to student/user
          if (roleSnapshot.hasData && roleSnapshot.data!.exists) {
            role = (roleSnapshot.data!.data() as Map<String, dynamic>)['role'] ?? 'user';
          }

          final bool isAdmin = role == 'admin';
          final bool isFaculty = role == 'faculty';
          final bool isViewer = role == 'viewer'; 
          // 'user' or 'student' will be treated as Student

          return SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 8.0 : 12.0),
              child: Column(
                children: [
                  // Welcome Card (Everyone sees this)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: isMobile ? 8 : 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.blue.shade400, Colors.blue.shade600], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.waving_hand, color: Colors.white, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Welcome Back, ${role.toUpperCase()}!', style: TextStyle(fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.bold, color: Colors.white)),
                              Text(user?.email ?? 'User', style: TextStyle(fontSize: isMobile ? 10 : 12, color: Colors.white70), overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isMobile ? 8 : 10),

                  // Stats Row (Only Admin and Faculty see this)
                  if (isAdmin || isFaculty)
                    Row(
                      children: [
                        Expanded(child: _buildCompactStat('Batches', Icons.class_, Colors.purple, 'batches', isMobile)),
                        SizedBox(width: isMobile ? 6 : 8),
                        Expanded(child: _buildCompactStat('Students', Icons.people, Colors.green, 'students', isMobile)),
                        SizedBox(width: isMobile ? 6 : 8),
                        Expanded(child: _buildCompactStat('Faculty', Icons.school, Colors.orange, 'faculties', isMobile)),
                        SizedBox(width: isMobile ? 6 : 8),
                        Expanded(child: _buildTodayAttendanceStat(isMobile)),
                      ],
                    ),
                  if (isAdmin || isFaculty) SizedBox(height: isMobile ? 8 : 10),

                  // Main Action Cards Grid (Conditionally Rendered)
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.45, // Fixed height for GridView
                    child: GridView.count(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: isMobile ? 6 : 8,
                      crossAxisSpacing: isMobile ? 6 : 8,
                      childAspectRatio: isMobile ? 1.2 : 1.5,
                      children: [
                        // ADMIN ONLY CARDS
                        if (isAdmin) _buildActionCard(context, 'Manage\nBatches', Icons.class_, Colors.purple, () { Navigator.push(context, MaterialPageRoute(builder: (context) => BatchManagementScreen())); }, isMobile),
                        if (isAdmin) _buildActionCard(context, 'Manage\nStudents', Icons.people, Colors.green, () { Navigator.push(context, MaterialPageRoute(builder: (context) => const StudentManagementScreen())); }, isMobile),
                        if (isAdmin) _buildActionCard(context, 'Manage\nFaculty', Icons.school, Colors.orange, () { Navigator.push(context, MaterialPageRoute(builder: (context) => FacultyManagementScreen())); }, isMobile),
                        
                        // ADMIN & FACULTY CARDS
                        if (isAdmin || isFaculty || isViewer) _buildActionCard(context, 'Mark\nAttendance', Icons.check_circle, Colors.blue, () { Navigator.push(context, MaterialPageRoute(builder: (context) => const MarkAttendanceScreen())); }, isMobile),
                        if (isAdmin || isFaculty || isViewer) _buildActionCard(context, 'Faculty\nAttendance', Icons.person, Colors.red, () { Navigator.push(context, MaterialPageRoute(builder: (context) => const FacultyAttendanceScreen())); }, isMobile),
                        if (isAdmin || isFaculty || isViewer) _buildActionCard(context, 'View\nReports', Icons.analytics, Colors.teal, () { Navigator.push(context, MaterialPageRoute(builder: (context) => const ViewReportsScreen())); }, isMobile),
                        
                        // ✅ NEW MANAGEMENT DASHBOARD CARD (Admin & Faculty Only)
                        if (isAdmin || isFaculty) _buildActionCard(context, 'Management\nDashboard', Icons.analytics_outlined, Colors.indigo, () { Navigator.push(context, MaterialPageRoute(builder: (context) => const ManagementDashboardScreen())); }, isMobile),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // --- LEAVE MANAGEMENT SECTION (Everyone sees this) ---
                  const Text('Leave Management', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  
                  Row(
                    children: [
                      Expanded(child: _buildActionCard(context, 'Apply\nLeave', Icons.flight_takeoff, Colors.indigo, () { Navigator.push(context, MaterialPageRoute(builder: (context) => const ApplyLeaveScreen())); }, isMobile)),
                      SizedBox(width: isMobile ? 6 : 8),
                      Expanded(child: _buildActionCard(context, 'My\nLeaves', Icons.history, Colors.pink, () { Navigator.push(context, MaterialPageRoute(builder: (context) => const MyLeavesScreen())); }, isMobile)),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Manage Leaves (Admin Only)
                  if (isAdmin)
                    SizedBox(
                      width: double.infinity,
                      child: _buildActionCard(context, 'Manage Leaves (Admin)', Icons.admin_panel_settings, Colors.deepOrange, () { Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageLeavesScreen())); }, isMobile),
                    ),
                  
                  // Branding Footer
                  const BrandingFooter(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCompactStat(String title, IconData icon, Color color, String collection, bool isMobile) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(collection).snapshots(),
      builder: (context, snapshot) {
        int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return Container(
          padding: EdgeInsets.all(isMobile ? 8 : 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.1), color.withOpacity(0.2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.15),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: isMobile ? 20 : 24),
              SizedBox(height: isMobile ? 4 : 6),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: isMobile ? 16 : 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: isMobile ? 9 : 11, 
                  color: Colors.grey.shade700
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTodayAttendanceStat(bool isMobile) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('student_attendance')
          .where('date', isEqualTo: _formatDate(DateTime.now())).snapshots(),
      builder: (context, snapshot) {
        int percentage = 0;
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final records = snapshot.data!.docs;
          int present = records.where((r) => (r.data() as Map<String, dynamic>)['status'] == 'Present').length;
          int total = records.length;
          percentage = total > 0 ? (present / total * 100).round() : 0;
        }

        return Container(
          padding: EdgeInsets.all(isMobile ? 8 : 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple.withOpacity(0.1), Colors.purple.withOpacity(0.2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.purple.withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.15),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.today, color: Colors.purple, size: 20),
              SizedBox(height: isMobile ? 4 : 6),
              Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: isMobile ? 16 : 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
              Text(
                'Today',
                style: TextStyle(
                  fontSize: isMobile ? 9 : 11, 
                  color: Colors.grey.shade700
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Widget _buildActionCard(BuildContext context, String title, IconData icon, Color color, VoidCallback? onTap, bool isMobile) {
    return GestureDetector(
      onTap: onTap ?? () {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title - Coming Soon!')));
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(isMobile ? 10 : 14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: isMobile ? 24 : 32),
            ),
            SizedBox(height: isMobile ? 6 : 8),
            Text(
              title,
              style: TextStyle(
                fontSize: isMobile ? 11 : 13,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
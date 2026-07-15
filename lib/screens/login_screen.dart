import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/session_manager.dart';
import '../services/role_service.dart';
import '../widgets/forgot_password_dialog.dart';
import '../widgets/branding_footer.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _isRegistering = false;
  bool _showPassword = false;
  String _errorMessage = '';

  // ✅ Student Portal Variables (Declared ONLY ONCE)
  bool _isStudentLogin = false;
  final String _commonStudentPassword = 'student123'; 
  final String _genericStudentEmail = 'student.portal@app.com';

  // Check if email is allowed (checks the 'users' collection)
  Future<bool> _isEmailAllowed(String email) async {
    try {
      final cleanEmail = email.trim().toLowerCase();
      print('🔍 Checking if email is allowed: $cleanEmail');
      
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: cleanEmail)
          .limit(1)
          .get();
      
      print('📊 Found ${querySnapshot.docs.length} documents');
      
      if (querySnapshot.docs.isNotEmpty) {
        final userData = querySnapshot.docs.first.data();
        print('✅ User found: ${userData['email']} with role: ${userData['role']}');
        return true;
      } else {
        print('❌ Email not found in users collection');
        return false;
      }
    } catch (e) {
      print('🔥 Error checking email: $e');
      setState(() => _errorMessage = 'Database error: ${e.toString()}');
      return false;
    }
  }

  // Check if account is blocked
  Future<bool> _isAccountBlocked(String email) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('login_attempts')
          .doc(email.trim().toLowerCase())
          .get();
      if (doc.exists) {
        final attempts = doc.data()?['attempts'] ?? 0;
        final blocked = doc.data()?['blocked'] ?? false;
        if (blocked || attempts >= 3) return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Record failed login attempt
  Future<void> _recordFailedAttempt(String email) async {
    final ref = FirebaseFirestore.instance
        .collection('login_attempts')
        .doc(email.trim().toLowerCase());
    final doc = await ref.get();
    int attempts = 1;
    if (doc.exists) attempts = (doc.data()?['attempts'] ?? 0) + 1;
    
    await ref.set({
      'attempts': attempts,
      'blocked': attempts >= 3,
      'lastAttempt': DateTime.now(),
      'email': email.trim().toLowerCase(),
    }, SetOptions(merge: true));
  }

  // Reset attempts after successful login
  Future<void> _resetAttempts(String email) async {
    await FirebaseFirestore.instance
        .collection('login_attempts')
        .doc(email.trim().toLowerCase())
        .set({'attempts': 0, 'blocked': false}, SetOptions(merge: true));
  }

  // Email & Password Login
  Future<void> _loginWithEmail() async {
    // 1. Basic empty check (adjusted for students)
    if (_emailController.text.trim().isEmpty) {
      setState(() => _errorMessage = _isStudentLogin ? 'Please enter your Roll Number' : 'Please enter email and password');
      return;
    }

    // 2. If it's a student, auto-fill the common password if it's empty
    if (_isStudentLogin && _passwordController.text.trim().isEmpty) {
      _passwordController.text = _commonStudentPassword;
    }

    // 3. For staff/admin, password is strictly required
    if (!_isStudentLogin && _passwordController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter email and password');
      return;
    }

    setState(() { _isLoading = true; _errorMessage = ''; });

    try {
      final email = _emailController.text.trim().toLowerCase();

      // ✅ STUDENT PORTAL LOGIN LOGIC
      if (_isStudentLogin) {
        final enteredRollNumber = _emailController.text.trim().toUpperCase();

        if (enteredRollNumber.isEmpty) {
          setState(() { _errorMessage = 'Please enter your Roll Number.'; _isLoading = false; });
          return;
        }

        // 1. Check the common password
        if (_passwordController.text.trim() != _commonStudentPassword) {
          setState(() { _errorMessage = 'Invalid common password.'; _isLoading = false; });
          return;
        }

        // 2. Query the students collection by rollNumber field
        final querySnapshot = await FirebaseFirestore.instance
            .collection('students')
            .where('rollNumber', isEqualTo: enteredRollNumber)
            .limit(1)
            .get();

        if (querySnapshot.docs.isEmpty) {
          setState(() { _errorMessage = 'Roll Number not found. Please contact admin.'; _isLoading = false; });
          return;
        }

        // 3. Get student data
        final studentDoc = querySnapshot.docs.first;
        final studentData = studentDoc.data() as Map<String, dynamic>;
        final studentName = studentData['name'] ?? 'Unknown Student';
        final batchId = studentData['batchId'] ?? '';

        // 4. Sign in with the generic Firebase account
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _genericStudentEmail,
          password: _commonStudentPassword
        );

        // 5. Save the student's info to active_sessions
        await FirebaseFirestore.instance.collection('active_sessions').add({
          'uid': FirebaseAuth.instance.currentUser!.uid,
          'role': 'student',
          'studentName': studentName,
          'rollNumber': enteredRollNumber,
          'batchId': batchId,
          'loginTime': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          // Note: If you don't use named routes, change this to:
          // Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
          Navigator.pushReplacementNamed(context, '/home'); 
        }
        return; // ✅ IMPORTANT: Stop here so it doesn't run the staff login logic
      }

      // ==========================================
      // STAFF / ADMIN LOGIN LOGIC (Below this line)
      // ==========================================
      if (await _isAccountBlocked(email)) {
        setState(() { _errorMessage = 'Account blocked after 3 failed attempts. Contact admin.'; _isLoading = false; });
        return;
      }
      
      if (!await _isEmailAllowed(email)) {
        setState(() { _errorMessage = 'Access denied. Your email is not authorized.'; _isLoading = false; });
        return;
      }

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email, 
        password: _passwordController.text.trim()
      );
      SessionManager().startSession();
      await RoleService().getUserRole();
      await _resetAttempts(email);
      
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        await _recordFailedAttempt(_emailController.text.trim());
        final doc = await FirebaseFirestore.instance
            .collection('login_attempts')
            .doc(_emailController.text.trim().toLowerCase())
            .get();
        final attempts = doc.data()?['attempts'] ?? 3;
        final remaining = 3 - attempts;
        if (remaining <= 0) {
          setState(() => _errorMessage = 'Account blocked after 3 failed attempts. Contact admin.');
        } else {
          setState(() => _errorMessage = 'Wrong password. $remaining attempt(s) remaining.');
        }
      } else if (e.code == 'user-not-found') {
        setState(() => _errorMessage = 'No account found with this email.');
      } else {
        setState(() => _errorMessage = 'Error: ${e.message ?? e.code}');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error: ${e.toString()}');
    }
    
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  // Register New User
  Future<void> _registerWithEmail() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter email and password');
      return;
    }
    if (_passwordController.text.trim().length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters');
      return;
    }
    setState(() { _isLoading = true; _errorMessage = ''; });

    try { 
      final email = _emailController.text.trim().toLowerCase();
      if (!await _isEmailAllowed(email)) {
        setState(() {
          _errorMessage = 'Access denied. Your email is not authorized.';
          _isLoading = false;
        });
        return;
      }

      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: email, 
            password: _passwordController.text.trim()
          );
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
            'email': email, 
            'createdAt': DateTime.now(), 
            'role': 'user' // Default role, admin can change it later
          });
      
      SessionManager().startSession();
      await RoleService().getUserRole();
      await _resetAttempts(email);
      
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        setState(() => _errorMessage = 'This email is already registered. Try Login.');
      } else {
        setState(() => _errorMessage = 'Error: ${e.message ?? e.code}');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error: ${e.toString()}');
    }
    
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  // Google Sign In
  Future<void> _loginWithGoogle() async {
    setState(() { _isLoading = true; _errorMessage = ''; });
    try {
      GoogleAuthProvider googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      googleProvider.setCustomParameters({
        'prompt': 'select_account',
        'client_id': '455567012708-243capj9rkrki8dq3pds46q3c58a73c2.apps.googleusercontent.com',
      });

      final userCredential = await FirebaseAuth.instance.signInWithPopup(googleProvider);
      final email = userCredential.user?.email ?? '';

      if (email.isEmpty) {
        await FirebaseAuth.instance.signOut();
        setState(() { 
          _errorMessage = 'Google login failed: No email received.'; 
          _isLoading = false;
        });
        return; 
      }

      if (await _isAccountBlocked(email)) {
        await FirebaseAuth.instance.signOut();
        setState(() { 
          _errorMessage = 'Account blocked after 3 failed attempts. Contact admin.'; 
          _isLoading = false;
        });
        return;
      }

      if (!await _isEmailAllowed(email)) {
        await FirebaseAuth.instance.signOut();
        setState(() { 
          _errorMessage = 'Access denied. Your Google email is not authorized.'; 
          _isLoading = false;
        });
        return; 
      }

      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'name': userCredential.user!.displayName,
        'email': email,
        'lastLogin': DateTime.now(),
        'role': 'user',
      }, SetOptions(merge: true));

      SessionManager().startSession();
      await RoleService().getUserRole();

    } catch (e) {
      setState(() => _errorMessage = 'Google error: ${e.toString()}');
    }
    
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 80, color: Colors.blue),
                const SizedBox(height: 24),
                Text(
                  _isRegistering ? 'Create Staff Account' : 'Welcome Back',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('Authorized users only', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),

                // STUDENT / STAFF TOGGLE
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ChoiceChip(
                      label: const Text('Staff/Admin'),
                      selected: !_isStudentLogin,
                      onSelected: (val) => setState(() { 
                        _isStudentLogin = false; 
                        _isRegistering = false; 
                        _errorMessage = '';
                        _emailController.clear();
                        _passwordController.clear();
                      }),
                      selectedColor: Colors.blue,
                    ),
                    const SizedBox(width: 12),
                    ChoiceChip(
                      label: const Text('Student'),
                      selected: _isStudentLogin,
                      onSelected: (val) => setState(() { 
                        _isStudentLogin = true; 
                        _isRegistering = false; 
                        _errorMessage = '';
                        _emailController.clear();
                        _passwordController.text = _commonStudentPassword; // Auto-fill on select
                      }),
                      selectedColor: Colors.indigo,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Email / Roll Number Field
                if (_isStudentLogin) ...[
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.text,
                    decoration: const InputDecoration(
                      labelText: 'Roll Number / Student ID',
                      hintText: 'e.g., 2011',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge),
                    ),
                  ),
                ] else ...[
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email)
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Password Field
                TextField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  readOnly: _isStudentLogin,
                  decoration: InputDecoration(
                    labelText: _isStudentLogin ? 'Common Password (Auto-filled)' : 'Password',
                    hintText: _isStudentLogin ? _commonStudentPassword : '', 
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: _isStudentLogin ? null : IconButton(
                      icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                    ),
                  ),
                ),
                
                // Forgot Password Button (Staff Only)
                if (!_isStudentLogin)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => showDialog(
                        context: context, 
                        builder: (context) => const ForgotPasswordDialog()
                      ),
                      child: const Text(
                        'Forgot Password?', 
                        style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w500)
                      ),
                    ),
                  ),
                const SizedBox(height: 8),

                // Error Message
                if (_errorMessage.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50, 
                      borderRadius: BorderRadius.circular(8), 
                      border: Border.all(color: Colors.red.shade200)
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_errorMessage, style: const TextStyle(color: Colors.red))),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

                // Login / Register Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : (_isRegistering ? _registerWithEmail : _loginWithEmail),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16), 
                      backgroundColor: Colors.blue, 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                    ),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white) 
                      : Text(
                          _isRegistering ? 'Register' : 'Login', 
                          style: const TextStyle(fontSize: 16, color: Colors.white)
                        ),
                  ),
                ),
                
                // Toggle Login/Register (Staff Only)
                if (!_isStudentLogin) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(() { 
                      _isRegistering = !_isRegistering; 
                      _errorMessage = ''; 
                    }),
                    child: Text(_isRegistering 
                      ? 'Already have an account? Login' 
                      : 'No account? Register here'
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Row(
                    children: [
                      Expanded(child: Divider()), 
                      Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('OR')), 
                      Expanded(child: Divider())
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Google Login Button (Staff Only)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _loginWithGoogle,
                      icon: const Icon(Icons.g_mobiledata, size: 28, color: Colors.red),
                      label: const Text('Sign in with Google', style: TextStyle(fontSize: 16)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14), 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                      ),
                    ),
                  ),
                ],
                const BrandingFooter(), 
              ],
            ),
          ),
        ),
      ),
    );
  }
}
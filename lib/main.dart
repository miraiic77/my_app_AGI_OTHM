import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/session_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
           if (snapshot.hasData) {
            // 2. WRAP YOUR MAIN SCREEN WITH THE LISTENER:
            return Listener(
              onPointerDown: (_) => SessionManager().resetTimer(), // Resets timer on any click/tap
              
              // 👇 REPLACE 'YourActualMainScreenName()' WITH YOUR REAL SCREEN 👇
              // Example: child: const DashboardScreen(), or child: const MainScreen(),
              child: const HomeScreen(),
            );
          } else {
            return const LoginScreen();
          }
        },
      ),
    );
  }
}
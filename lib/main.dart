import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'services/auth_service.dart';
import 'screens/splash_screens.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Power Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // FIXED: Added 'ColorScheme' back right before '.fromSeed'
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // CHANGED: Instead of loading LoginScreen directly, we load the gatekeeper
      home: const SplashScreen(),
    );
  }
}

// ADDED: The gatekeeper that switches between Login and Home automatically
class AppGatekeeper extends StatelessWidget {
  const AppGatekeeper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // While checking Firebase connection, show a clean loading spinner
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If a user session is active, go straight to navigation tabs
        if (snapshot.hasData) {
          return const MainNavigationScreen();
        }

        // If no user is logged in, show the login interface
        return const LoginScreen();
      },
    );
  }
}

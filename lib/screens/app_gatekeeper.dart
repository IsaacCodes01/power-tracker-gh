import 'package:flutter/material.dart';
import 'main_navigation_screen.dart';
import 'auth/login_screen.dart';
import '../services/auth_service.dart';

// Watches the user's login status live. Automatically shows the main
// app if someone's signed in, or the login screen if they're not —
// this is the single source of truth for post-auth navigation.
class AppGatekeeper extends StatelessWidget {
  const AppGatekeeper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            snapshot.connectionState == ConnectionState.none) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return const MainNavigationScreen();
        }

        return const LoginScreen();
      },
    );
  }
}

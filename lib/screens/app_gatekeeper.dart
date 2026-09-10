import 'package:flutter/material.dart';
import 'main_navigation_screen.dart';
import 'auth/login_screen.dart';
import 'auth/verify_email_gate_screen.dart';
import '../services/auth_service.dart';

// Watches the user's login status live. Automatically shows the main
// app if someone's signed in AND verified, a dedicated verification
// screen if they're signed in but haven't verified yet, or the login
// screen if they're not signed in at all — this is the single source
// of truth for post-auth navigation.
//
// IMPORTANT: this is the ONLY place that decides where a user lands
// after auth. Screens like LoginScreen should not also try to manually
// navigate to MainNavigationScreen on success — doing so races against
// this StreamBuilder (whichever one runs first "wins" a screen flash,
// then the other corrects it a moment later), which previously caused
// unverified users to see the app flash in and immediately back out.
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

        final user = snapshot.data;
        if (user != null) {
          if (!user.emailVerified) {
            return const VerifyEmailGateScreen();
          }
          return const MainNavigationScreen();
        }

        return const LoginScreen();
      },
    );
  }
}

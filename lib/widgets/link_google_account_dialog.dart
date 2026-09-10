import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../screens/auth/forgot_password_screen.dart';

// Shown when someone taps "Continue with Google" using an email that
// already has a password-based account. Asks for that password, signs
// them in with it, then links the Google credential onto the same
// account so either method works from now on.
// Returns the linked UserCredential on success, or null if cancelled.
Future<UserCredential?> showLinkGoogleAccountDialog(
  BuildContext context, {
  required String email,
  required AuthCredential pendingCredential,
}) async {
  final passwordController = TextEditingController();
  bool isChecking = false;
  String? error;

  final result = await showDialog<UserCredential>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Account Already Exists'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'An account already exists for $email with a password. '
                  'Enter that password to link your Google sign-in, so you '
                  'can use either method from now on.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    errorText: error,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: isChecking
                        ? null
                        : () {
                            // Close this dialog and send them to the normal
                            // reset-password flow instead of linking.
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ForgotPasswordScreen(),
                              ),
                            );
                          },
                    child: const Text('Forgot password?'),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isChecking ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isChecking
                    ? null
                    : () async {
                        setState(() {
                          isChecking = true;
                          error = null;
                        });
                        try {
                          final linked = await AuthService()
                              .linkGoogleWithPassword(
                                email: email,
                                password: passwordController.text,
                                pendingCredential: pendingCredential,
                              );
                          if (context.mounted) {
                            Navigator.pop(context, linked);
                          }
                        } catch (e) {
                          setState(() {
                            error = e.toString();
                            isChecking = false;
                          });
                        }
                      },
                child: isChecking
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Link Account'),
              ),
            ],
          );
        },
      );
    },
  );

  return result;
}

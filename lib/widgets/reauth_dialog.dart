import 'package:flutter/material.dart';
import '../services/auth_service.dart';

// Shows a small dialog asking the user to re-enter their password.
// Returns true if re-authentication succeeded, false/null otherwise.
Future<bool> showReauthDialog(BuildContext context) async {
  final passwordController = TextEditingController();
  bool isChecking = false;
  String? error;

  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Confirm Your Password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'For your security, please re-enter your password to continue.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    errorText: error,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isChecking
                    ? null
                    : () async {
                        setState(() => isChecking = true);
                        try {
                          await AuthService().reauthenticate(
                            passwordController.text,
                          );
                          if (context.mounted) Navigator.pop(context, true);
                        } catch (e) {
                          setState(() {
                            error = 'Incorrect password. Try again.';
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
                    : const Text('Confirm'),
              ),
            ],
          );
        },
      );
    },
  );

  return result ?? false;
}

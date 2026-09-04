import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../screens/admin/admin_shell_screen.dart';
import '../services/firestore_service.dart';
import 'app_snackbar.dart';

class AdminModeToggle extends StatefulWidget {
  const AdminModeToggle({super.key});

  @override
  State<AdminModeToggle> createState() => _AdminModeToggleState();
}

class _AdminModeToggleState extends State<AdminModeToggle> {
  bool _isAdmin = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  Future<void> _checkRole() async {
    final uid = AuthService().currentUser?.uid;
    if (uid != null) {
      final role = await AuthService().getUserRole(uid);
      if (mounted) setState(() => _isAdmin = role == 'admin');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || !_isAdmin) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () async {
        final uid = AuthService().currentUser?.uid;
        if (uid == null) return;

        final profile = await FirestoreService().getUserProfile(uid);
        if (!context.mounted) return;

        final adminPin = profile?.adminPin;
        final hasPin = adminPin != null && adminPin.isNotEmpty;

        final verified = hasPin
            ? await _showPinDialog(context, expectedPin: adminPin)
            : await _showSetPinDialog(context, uid: uid);

        if (verified && context.mounted) {
          AppSnackbar.show(
            context,
            message: 'Login successful',
            type: AppMessageType.success,
          );
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminShellScreen()),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Admin',
          style: TextStyle(
            color: Colors.deepPurple,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

Future<bool> _showPinDialog(
  BuildContext context, {
  required String expectedPin,
}) async {
  final controller = TextEditingController();
  String? error;

  return await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Enter Admin PIN'),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              decoration: InputDecoration(errorText: error),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (controller.text == expectedPin) {
                    Navigator.pop(context, true);
                  } else {
                    setState(() => error = 'Incorrect PIN');
                  }
                },
                child: const Text('Confirm'),
              ),
            ],
          ),
        ),
      ) ??
      false;
}

Future<bool> _showSetPinDialog(
  BuildContext context, {
  required String uid,
}) async {
  final controller = TextEditingController();

  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Set Your Admin PIN'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            decoration: const InputDecoration(hintText: '4-digit PIN'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (controller.text.length == 4) {
                  await FirestoreService().setAdminPin(uid, controller.text);
                  if (context.mounted) Navigator.pop(context, true);
                }
              },
              child: const Text('Set PIN'),
            ),
          ],
        ),
      ) ??
      false;
}

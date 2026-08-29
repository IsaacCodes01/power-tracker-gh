import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../screens/admin/admin_shell_screen.dart';

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
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminShellScreen()),
        );
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

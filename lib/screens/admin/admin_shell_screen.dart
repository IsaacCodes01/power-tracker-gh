import 'package:flutter/material.dart';
import 'admin_dashboard_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_announcements_screen.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/admin_mode_toggle.dart';

class AdminShellScreen extends StatefulWidget {
  const AdminShellScreen({super.key});

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  int _currentIndex = 0;

  final _titles = const ['Dashboard', 'Reports', 'Send Announcements'];

  @override
  Widget build(BuildContext context) {
    final screens = [
      AdminDashboardScreen(
        onNavigateToReports: () => setState(() => _currentIndex = 1),
      ),
      const AdminReportsScreen(),
      const AdminAnnouncementsScreen(),
    ];
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: _currentIndex != 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _currentIndex = 0),
              )
            : null,
        backgroundColor: Colors.deepPurple[900],
        foregroundColor: Colors.white,
        elevation: 0,
        title: null,
        flexibleSpace: SafeArea(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: _currentIndex != 0 ? 56 : 16,
                child: Text(
                  _titles[_currentIndex],
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
              if (_currentIndex == 0)
                const Align(
                  alignment: Alignment.center,
                  child: AdminModeToggle(isInsideAdminMode: true),
                ),
              if (_currentIndex == 0)
                const Positioned(right: 8, child: NotificationBell()),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          screens[_currentIndex],

          // FLOATING HAMBURGER — sits on the screen itself, not the app bar.
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              backgroundColor: Colors.deepPurple[900],
              onPressed: () => _showAdminMenu(context),
              child: const Icon(Icons.menu, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showAdminMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _menuTile('Dashboard', Icons.dashboard, 0),
              _menuTile('Reports', Icons.list_alt, 1),
              _menuTile('Send Announcements', Icons.campaign, 2),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _menuTile(String title, IconData icon, int index) {
    final isSelected = _currentIndex == index;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Colors.deepPurple[900] : Colors.grey[700],
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.deepPurple[900] : Colors.black87,
        ),
      ),
      onTap: () {
        setState(() => _currentIndex = index);
        Navigator.pop(context);
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:power_tracker_gh/screens/outage/outage_list_screen.dart';
import 'home/home_screen.dart';
import 'map/outage_map_screen.dart';
import 'outage/report_outage_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import '../services/auth_service.dart';
import 'settings/settings_screen.dart';
import '../services/connectivity_service.dart';
import 'dart:async';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final _authService = AuthService();

  bool _isAdmin = false;
  bool _isLoadingRole = true;

  final _connectivityService = ConnectivityService();
  StreamSubscription<bool>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _checkInitialConnection();
    _connectivitySubscription = _connectivityService.onConnectivityChanged
        .listen(_handleConnectivityChange);
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkInitialConnection() async {
    final connected = await _connectivityService.hasConnection();
    _handleConnectivityChange(connected);
  }

  void _handleConnectivityChange(bool connected) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentMaterialBanner();

    if (!connected) {
      messenger.showMaterialBanner(
        MaterialBanner(
          backgroundColor: Colors.red,
          content: const Text(
            'No internet connection. Please turn on WiFi or mobile data.',
            style: TextStyle(color: Colors.white),
          ),
          leading: const Icon(Icons.wifi_off, color: Colors.white),
          actions: [
            TextButton(
              onPressed: () => messenger.hideCurrentMaterialBanner(),
              child: const Text(
                'DISMISS',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _loadUserRole() async {
    final uid = _authService.currentUser?.uid;
    if (uid != null) {
      final role = await _authService.getUserRole(uid);
      setState(() {
        _isAdmin = role == 'admin';
        _isLoadingRole = false;
      });
    } else {
      setState(() => _isLoadingRole = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRole) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // The screen list and nav items are built dynamically — the Admin
    // tab only gets added to either list at all if the account is admin.
    final screens = [
      HomeScreen(
        onNavigateToReport: () => setState(() => _currentIndex = 2),
        onNavigateToOutages: () => setState(() => _currentIndex = 3),
      ),
      const OutageMapScreen(),
      const ReportOutageScreen(),
      const OutageListScreen(),
      const SettingsScreen(),
      if (_isAdmin) const AdminDashboardScreen(),
    ];

    final navItems = [
      const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
      const BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
      const BottomNavigationBarItem(
        icon: Icon(Icons.add_circle),
        label: 'Add Report',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.flash_off),
        label: 'Outages',
      ),
      if (_isAdmin)
        const BottomNavigationBarItem(
          icon: Icon(Icons.admin_panel_settings),
          label: 'Admin',
        ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.settings),
        label: 'Settings',
      ),
    ];

    // Keeps the index safely in range if role finishes loading
    // after a tap already happened.
    final safeIndex = _currentIndex < screens.length ? _currentIndex : 0;

    return Scaffold(
      body: screens[safeIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: safeIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey[600],
        items: navItems,
      ),
    );
  }
}

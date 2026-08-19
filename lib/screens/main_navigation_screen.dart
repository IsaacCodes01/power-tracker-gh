import 'package:flutter/material.dart';
import 'package:power_tracker_gh/screens/outage/outage_list_screen.dart';
import 'home/home_screen.dart';
import 'map/outage_map_screen.dart';
import 'outage/report_outage_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const OutageMapScreen(),
    const ReportOutageScreen(),
    const OutageListScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        type: BottomNavigationBarType.fixed,
        // FIXED: Change these colors so they pop contrastingly against the white bar
        backgroundColor: Colors.white,
        // Forces the bottom bar background to stay solid
        selectedItemColor: Colors.deepPurple,
        // Force selected icon to match your deep purple theme
        unselectedItemColor: Colors.grey[600],
        // Darken the unselected grey so it stands out cleanly
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle),
            label: 'Add Report',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.flash_off),
            label: 'Outages',
          ),
        ],
      ),
    );
  }
}

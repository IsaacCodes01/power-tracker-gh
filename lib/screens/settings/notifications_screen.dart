import 'package:flutter/material.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _allNotifications = true;
  bool _locationAlerts = true;
  bool _userActionAlerts = true;
  bool _verificationAlerts = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.grey[100],
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Enable All Notifications'),
                value: _allNotifications,
                activeThumbColor: Colors.deepPurple,
                onChanged: (v) => setState(() {
                  _allNotifications = v;
                  _locationAlerts = v;
                  _userActionAlerts = v;
                  _verificationAlerts = v;
                }),
              ),
              SwitchListTile(
                title: const Text('Location-Based Alerts'),
                value: _locationAlerts,
                activeThumbColor: Colors.deepPurple,
                onChanged: (v) => setState(() => _locationAlerts = v),
              ),
              SwitchListTile(
                title: const Text('User Action Alerts'),
                value: _userActionAlerts,
                activeThumbColor: Colors.deepPurple,
                onChanged: (v) => setState(() => _userActionAlerts = v),
              ),
              SwitchListTile(
                title: const Text('Report Verification Alerts'),
                value: _verificationAlerts,
                activeThumbColor: Colors.deepPurple,
                onChanged: (v) => setState(() => _verificationAlerts = v),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

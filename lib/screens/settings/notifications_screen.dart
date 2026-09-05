import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/app_snackbar.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  bool _isLoading = true;
  bool _powerRestored = true;
  bool _statusUpdates = true;
  bool _verification = true;
  bool _announcements = true;
  bool _maintenance = true;

  String? _uid;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final uid = _authService.currentUser?.uid;
    _uid = uid;
    if (uid != null) {
      final profile = await _firestoreService.getUserProfile(uid);
      if (profile != null && mounted) {
        setState(() {
          _powerRestored = profile.notifyPowerRestored;
          _statusUpdates = profile.notifyStatusUpdates;
          _verification = profile.notifyVerification;
          _announcements = profile.notifyAnnouncements;
          _maintenance = profile.notifyMaintenance;
        });
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  bool get _allEnabled =>
      _powerRestored && _statusUpdates && _verification && _announcements &&
          _maintenance;

  Future<void> _updatePref(String key, bool value, String label) async {
    if (_uid == null) return;
    await _firestoreService.updateNotificationPreferences(_uid!, {key: value});
    if (mounted) {
      AppSnackbar.show(
        context,
        message: value
            ? '$label notifications enabled'
            : '$label notifications turned off',
        type: value ? AppMessageType.success : AppMessageType.info,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: SwitchListTile(
                title: const Text('Enable All Notifications'),
                value: _allEnabled,
                activeThumbColor: Colors.deepPurple,
                onChanged: (v) {
                  setState(() {
                    _powerRestored = v;
                    _statusUpdates = v;
                    _verification = v;
                    _announcements = v;
                    _maintenance = v;
                  });
                  _firestoreService.updateNotificationPreferences(_uid!, {
                    'notifyPowerRestored': v,
                    'notifyStatusUpdates': v,
                    'notifyVerification': v,
                    'notifyAnnouncements': v,
                    'notifyMaintenance': v,
                  });
                  AppSnackbar.show(context,
                      message: v
                          ? 'All notifications enabled'
                          : 'All notifications turned off',
                      type: v
                          ? AppMessageType.success
                          : AppMessageType.info);
                },
              ),
            ),
            const SizedBox(height: 16),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Power Restored'),
                    subtitle: const Text(
                        'When an outage you reported or confirmed is fixed'),
                    value: _powerRestored,
                    activeThumbColor: Colors.deepPurple,
                    onChanged: (v) {
                      setState(() => _powerRestored = v);
                      _updatePref('notifyPowerRestored', v, 'Power Restored');
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Status Updates'),
                    subtitle: const Text('Investigating or repairing progress'),
                    value: _statusUpdates,
                    activeThumbColor: Colors.deepPurple,
                    onChanged: (v) {
                      setState(() => _statusUpdates = v);
                      _updatePref('notifyStatusUpdates', v, 'Status Update');
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Report Verified'),
                    subtitle: const Text(
                        'When your report is verified by an admin'),
                    value: _verification,
                    activeThumbColor: Colors.deepPurple,
                    onChanged: (v) {
                      setState(() => _verification = v);
                      _updatePref('notifyVerification', v, 'Report Verified');
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Announcements'),
                    subtitle: const Text('General updates from admins'),
                    value: _announcements,
                    activeThumbColor: Colors.deepPurple,
                    onChanged: (v) {
                      setState(() => _announcements = v);
                      _updatePref('notifyAnnouncements', v, 'Announcement');
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Maintenance Notices'),
                    subtitle: const Text('Scheduled maintenance in your area'),
                    value: _maintenance,
                    activeThumbColor: Colors.deepPurple,
                    onChanged: (v) {
                      setState(() => _maintenance = v);
                      _updatePref('notifyMaintenance', v, 'Maintenance Notice');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
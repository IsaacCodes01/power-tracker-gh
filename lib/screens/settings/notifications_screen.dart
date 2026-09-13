import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/network_guard.dart';
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
      _powerRestored &&
      _statusUpdates &&
      _verification &&
      _announcements &&
      _maintenance;

  // Reverts a toggle back on failure instead of leaving it showing a
  // value that doesn't actually match what's saved — previously a
  // failed write left the switch silently out of sync with the
  // database, with no error and no way to tell.
  Future<void> _updatePref(
    String key,
    bool value,
    String label,
    VoidCallback revert,
  ) async {
    if (_uid == null) return;
    try {
      await _firestoreService.updateNotificationPreferences(_uid!, {
        key: value,
      });
      if (mounted) {
        AppSnackbar.show(
          context,
          message: value
              ? '$label notifications enabled'
              : '$label notifications turned off',
          type: value ? AppMessageType.success : AppMessageType.info,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(revert);
        AppSnackbar.show(
          context,
          message:
              (e is NetworkTimeoutException || e is NetworkUnavailableException)
              ? e.toString()
              : 'Unable to save that right now. Please try again.',
          type: AppMessageType.error,
        );
      }
    }
  }

  Future<void> _updateAll(bool value) async {
    if (_uid == null) return;
    final previous = (
      powerRestored: _powerRestored,
      statusUpdates: _statusUpdates,
      verification: _verification,
      announcements: _announcements,
      maintenance: _maintenance,
    );
    setState(() {
      _powerRestored = value;
      _statusUpdates = value;
      _verification = value;
      _announcements = value;
      _maintenance = value;
    });
    try {
      await _firestoreService.updateNotificationPreferences(_uid!, {
        'notifyPowerRestored': value,
        'notifyStatusUpdates': value,
        'notifyVerification': value,
        'notifyAnnouncements': value,
        'notifyMaintenance': value,
      });
      if (mounted) {
        AppSnackbar.show(
          context,
          message: value
              ? 'All notifications enabled'
              : 'All notifications turned off',
          type: value ? AppMessageType.success : AppMessageType.info,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _powerRestored = previous.powerRestored;
          _statusUpdates = previous.statusUpdates;
          _verification = previous.verification;
          _announcements = previous.announcements;
          _maintenance = previous.maintenance;
        });
        AppSnackbar.show(
          context,
          message:
              (e is NetworkTimeoutException || e is NetworkUnavailableException)
              ? e.toString()
              : 'Unable to save that right now. Please try again.',
          type: AppMessageType.error,
        );
      }
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
                      onChanged: _updateAll,
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
                            'When an outage you reported or confirmed is fixed',
                          ),
                          value: _powerRestored,
                          activeThumbColor: Colors.deepPurple,
                          onChanged: (v) {
                            final previous = _powerRestored;
                            setState(() => _powerRestored = v);
                            _updatePref(
                              'notifyPowerRestored',
                              v,
                              'Power Restored',
                              () => _powerRestored = previous,
                            );
                          },
                        ),
                        SwitchListTile(
                          title: const Text('Status Updates'),
                          subtitle: const Text(
                            'Investigating or repairing progress',
                          ),
                          value: _statusUpdates,
                          activeThumbColor: Colors.deepPurple,
                          onChanged: (v) {
                            final previous = _statusUpdates;
                            setState(() => _statusUpdates = v);
                            _updatePref(
                              'notifyStatusUpdates',
                              v,
                              'Status Update',
                              () => _statusUpdates = previous,
                            );
                          },
                        ),
                        SwitchListTile(
                          title: const Text('Report Verified'),
                          subtitle: const Text(
                            'When your report is verified by an admin',
                          ),
                          value: _verification,
                          activeThumbColor: Colors.deepPurple,
                          onChanged: (v) {
                            final previous = _verification;
                            setState(() => _verification = v);
                            _updatePref(
                              'notifyVerification',
                              v,
                              'Report Verified',
                              () => _verification = previous,
                            );
                          },
                        ),
                        SwitchListTile(
                          title: const Text('Announcements'),
                          subtitle: const Text('General updates from admins'),
                          value: _announcements,
                          activeThumbColor: Colors.deepPurple,
                          onChanged: (v) {
                            final previous = _announcements;
                            setState(() => _announcements = v);
                            _updatePref(
                              'notifyAnnouncements',
                              v,
                              'Announcement',
                              () => _announcements = previous,
                            );
                          },
                        ),
                        SwitchListTile(
                          title: const Text('Maintenance Notices'),
                          subtitle: const Text(
                            'Scheduled maintenance in your area',
                          ),
                          value: _maintenance,
                          activeThumbColor: Colors.deepPurple,
                          onChanged: (v) {
                            final previous = _maintenance;
                            setState(() => _maintenance = v);
                            _updatePref(
                              'notifyMaintenance',
                              v,
                              'Maintenance Notice',
                              () => _maintenance = previous,
                            );
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

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/connectivity_service.dart';
import '../../utils/network_guard.dart';
import '../../models/outage_report.dart';
import '../../widgets/app_snackbar.dart';
import '../../models/notification_item.dart';
import '../map/outage_map_screen.dart';
import '../auth/signup_screen.dart' show purpleButtonStyle;
import 'edit_report_screen.dart';
import 'report_outage_screen.dart';

class OutageDetailScreen extends StatefulWidget {
  final OutageReport report;

  const OutageDetailScreen({super.key, required this.report});

  @override
  State<OutageDetailScreen> createState() => _OutageDetailScreenState();
}

class _OutageDetailScreenState extends State<OutageDetailScreen> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  final _connectivityService = ConnectivityService();

  bool _isAdmin = false;
  bool _isLoadingRole = true;
  bool _isUpdating = false;

  // Staged "Please wait" -> "Please wait, checking your connection..."
  // caption, same pattern used across the rest of the app — plain
  // wording for a normal-speed action, only escalates after a couple
  // seconds if something's genuinely taking a while.
  bool _showConnectionMessage = false;
  Timer? _waitMessageTimer;

  void _startWaitMessageTimer() {
    _waitMessageTimer?.cancel();
    _showConnectionMessage = false;
    _waitMessageTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showConnectionMessage = true);
    });
  }

  void _resetWaitMessage() {
    _waitMessageTimer?.cancel();
    _showConnectionMessage = false;
  }

  late OutageReport _report;

  @override
  void initState() {
    super.initState();
    _report = widget.report;
    _loadUserRole();
  }

  @override
  void dispose() {
    _waitMessageTimer?.cancel();
    super.dispose();
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

  bool get _canMarkRestored {
    final uid = _authService.currentUser?.uid;
    final isReporter = uid != null && uid == _report.reporterId;
    return isReporter || _isAdmin;
  }

  bool get _hasConfirmed {
    final uid = _authService.currentUser?.uid;
    return uid != null && _report.confirmedByUserIds.contains(uid);
  }

  // Shown to confirmers once a report they confirmed gets marked
  // restored — the reporter's power being back doesn't necessarily mean
  // it's back for everyone who confirmed the same outage. Stops showing
  // once they've answered either way.
  bool get _needsRestorationCheck {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return false;
    return _report.status == OutageStatus.restored &&
        _report.confirmedByUserIds.contains(uid) &&
        !_report.restorationCheckRespondedUserIds.contains(uid);
  }

  Future<void> _respondToRestorationCheck(bool stillOff) async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;

    try {
      await _firestoreService.respondToRestorationCheck(_report.id, uid);
      if (mounted) {
        setState(() {
          _report = _report.copyWith(
            restorationCheckRespondedUserIds: [
              ..._report.restorationCheckRespondedUserIds,
              uid,
            ],
          );
        });
      }
    } catch (_) {
      // Not critical enough to interrupt them with an error — worst
      // case the check just shows again next time they open the report.
    }

    if (!mounted) return;

    if (stillOff) {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Sorry to hear that'),
          content: const Text(
            'Since this seems separate from the original report, let\'s '
            'log it as its own outage so it can be looked into for your '
            'specific location.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Not now'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReportOutageScreen()),
                );
              },
              style: purpleButtonStyle(),
              child: const Text('Report Outage'),
            ),
          ],
        ),
      );
    } else {
      AppSnackbar.show(
        context,
        message: 'Thanks for confirming!',
        type: AppMessageType.success,
      );
    }
  }

  Color _statusColor(OutageStatus status) {
    switch (status) {
      case OutageStatus.restored:
        return Colors.green;
      case OutageStatus.reported:
        return Colors.redAccent;
      case OutageStatus.investigating:
        return Colors.orange;
      case OutageStatus.repairing:
        return Colors.blue;
    }
  }

  String _statusLabel(OutageStatus status) {
    switch (status) {
      case OutageStatus.restored:
        return 'Resolved';
      case OutageStatus.reported:
        return 'Reported';
      case OutageStatus.investigating:
        return 'Investigating';
      case OutageStatus.repairing:
        return 'Fixing';
    }
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }

  Future<void> _confirmOutage() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null || _hasConfirmed) return;

    final hasConnection = await _connectivityService.hasConnection();
    if (!hasConnection) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'No internet connection. Please check your network.',
          type: AppMessageType.error,
        );
      }
      return;
    }

    setState(() => _isUpdating = true);
    _startWaitMessageTimer();

    final hasRealAccess = await _connectivityService.hasRealInternetAccess();
    if (!hasRealAccess) {
      if (mounted) {
        _resetWaitMessage();
        setState(() => _isUpdating = false);
        AppSnackbar.show(
          context,
          message: const NetworkUnavailableException().toString(),
          type: AppMessageType.error,
        );
      }
      return;
    }

    try {
      await _firestoreService.confirmOutage(_report.id, uid);
      setState(() {
        _report = _report.copyWith(
          confirmedByUserIds: [..._report.confirmedByUserIds, uid],
        );
      });
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message:
            (e is NetworkTimeoutException || e is NetworkUnavailableException)
            ? e.toString()
            : 'Unable to confirm right now. Please try again.',
        type: AppMessageType.error,
      );
    } finally {
      _resetWaitMessage();
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _markAsRestored() async {
    final hasConnection = await _connectivityService.hasConnection();
    if (!hasConnection) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'No internet connection. Please check your network.',
          type: AppMessageType.error,
        );
      }
      return;
    }

    setState(() => _isUpdating = true);
    _startWaitMessageTimer();

    final hasRealAccess = await _connectivityService.hasRealInternetAccess();
    if (!hasRealAccess) {
      if (mounted) {
        _resetWaitMessage();
        setState(() => _isUpdating = false);
        AppSnackbar.show(
          context,
          message: const NetworkUnavailableException().toString(),
          type: AppMessageType.error,
        );
      }
      return;
    }

    try {
      await _firestoreService.updateReport(_report.id, {
        'status': OutageStatus.restored.name,
        'endTime': Timestamp.now(),
      });

      setState(() {
        _report = _report.copyWith(
          status: OutageStatus.restored,
          endTime: DateTime.now(),
        );
      });

      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Marked as restored',
          type: AppMessageType.info,
        );
      }

      // Notify everyone who confirmed this outage that it's now
      // restored. Sent in parallel with each send wrapped individually
      // — one confirmer's notification failing (a stale token, a blip)
      // must not stop the others from being notified, and none of this
      // should be able to undo the restore action above, which has
      // already succeeded by this point.
      final uid = _authService.currentUser?.uid;
      await Future.wait(
        _report.confirmedByUserIds
            .where((confirmerId) => confirmerId != uid)
            .map((confirmerId) async {
              try {
                await _firestoreService.createNotification(
                  userId: confirmerId,
                  type: NotificationType.powerRestored,
                  title: 'Power Restored',
                  message: '${_report.area} has been marked as restored.',
                  relatedReportId: _report.id,
                );
              } catch (_) {
                // Best-effort — the restore itself already succeeded and
                // was already confirmed to the user above; a single
                // notification failing here shouldn't surface as an
                // error about the action they actually asked for.
              }
            }),
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message:
            (e is NetworkTimeoutException || e is NetworkUnavailableException)
            ? e.toString()
            : 'Unable to update status right now. Please try again.',
        type: AppMessageType.error,
      );
    } finally {
      _resetWaitMessage();
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(_report.area),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_canMarkRestored && _report.status != OutageStatus.restored)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit report',
              onPressed: () async {
                final updated = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditReportScreen(report: _report),
                  ),
                );
                if (updated == true) {
                  final refreshed = await _firestoreService.getReport(
                    _report.id,
                  );
                  if (refreshed != null && mounted) {
                    setState(() => _report = refreshed);
                  }
                }
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_needsRestorationCheck)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.help_outline,
                          color: Colors.orange[800],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'This was marked as restored — is your light '
                            'really back?',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _respondToRestorationCheck(true),
                            child: const Text('No, still off'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _respondToRestorationCheck(false),
                            style: purpleButtonStyle(),
                            child: const Text('Yes, it\'s back'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200, width: 1.2),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // STATUS + TIME
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(_report.status).withAlpha(30),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _statusLabel(_report.status),
                          style: TextStyle(
                            color: _statusColor(_report.status),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Text(
                        _timeAgo(_report.createdAt),
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // SEVERITY + TYPE
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Severity',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 9,
                                    color: severityColor(_report.severity),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    _report.severity.name[0].toUpperCase() +
                                        _report.severity.name.substring(1),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: severityColor(_report.severity),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Type',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(
                                    outageTypeIcon(_report.outageType),
                                    size: 14,
                                    color: Colors.deepPurple,
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      outageTypeLabel(_report.outageType),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // DESCRIPTION
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.description_outlined,
                        size: 16,
                        color: Colors.black,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _report.description,
                          style: const TextStyle(fontSize: 13, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // MAP PREVIEW — kept non-interactive (IgnorePointer)
                  // internally so it can't be panned/zoomed accidentally
                  // while scrolling this page, but the whole preview is
                  // now tappable to open the real, full map focused on
                  // this exact location — previously it was just a
                  // static image with no way to actually open the map.
                  if (_report.latitude != 0.0 && _report.longitude != 0.0)
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OutageMapScreen(
                              focusLatitude: _report.latitude,
                              focusLongitude: _report.longitude,
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          height: 120,
                          child: Stack(
                            children: [
                              IgnorePointer(
                                child: FlutterMap(
                                  options: MapOptions(
                                    initialCenter: LatLng(
                                      _report.latitude,
                                      _report.longitude,
                                    ),
                                    initialZoom: 15,
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate:
                                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      userAgentPackageName:
                                          'com.isaacotabil.powertrackergh',
                                    ),
                                    MarkerLayer(
                                      markers: [
                                        Marker(
                                          point: LatLng(
                                            _report.latitude,
                                            _report.longitude,
                                          ),
                                          width: 34,
                                          height: 34,
                                          child: Icon(
                                            Icons.location_pin,
                                            color: _statusColor(_report.status),
                                            size: 34,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                right: 8,
                                bottom: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withAlpha(140),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.open_in_full,
                                        size: 11,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'View full map',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),

                  // CONFIRMED-BY AVATARS
                  FutureBuilder<List<String>>(
                    future: _firestoreService.getUserInitials(
                      _report.confirmedByUserIds,
                    ),
                    builder: (context, snapshot) {
                      final count = _report.confirmedByUserIds.length;
                      final initials = snapshot.data;
                      return Row(
                        children: [
                          if (count > 0)
                            SizedBox(
                              height: 26,
                              width: count * 16.0 + 14,
                              child: Stack(
                                children: List.generate(count, (i) {
                                  final label =
                                      (initials != null && i < initials.length)
                                      ? initials[i]
                                      : '?';
                                  return Positioned(
                                    left: i * 16.0,
                                    child: CircleAvatar(
                                      radius: 13,
                                      backgroundColor: Colors.deepPurple[200],
                                      child: Text(
                                        label,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          const SizedBox(width: 6),
                          Text(
                            '$count household${count == 1 ? '' : 's'} affected',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // CONFIRM BUTTON
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: (_isUpdating || _hasConfirmed)
                    ? null
                    : _confirmOutage,
                icon: const Icon(Icons.people, size: 18),
                label: Text(
                  _hasConfirmed ? 'You confirmed this' : "I'm also affected",
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // MARK AS RESTORED — reporter or admin only
            if (!_isLoadingRole &&
                _canMarkRestored &&
                _report.status != OutageStatus.restored)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isUpdating ? null : _markAsRestored,
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('Mark as Restored'),
                  style: purpleButtonStyle().copyWith(
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
            if (_isUpdating)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Center(
                  child: Text(
                    _showConnectionMessage
                        ? 'Please wait, checking your connection…'
                        : 'Please wait…',
                    style: TextStyle(
                      color: Colors.deepPurple.withValues(alpha: 0.7),
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

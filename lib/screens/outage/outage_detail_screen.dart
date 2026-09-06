import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../models/outage_report.dart';
import '../../widgets/app_snackbar.dart';
import '../../models/notification_item.dart';
import 'edit_report_screen.dart';

class OutageDetailScreen extends StatefulWidget {
  final OutageReport report;

  const OutageDetailScreen({super.key, required this.report});

  @override
  State<OutageDetailScreen> createState() => _OutageDetailScreenState();
}

class _OutageDetailScreenState extends State<OutageDetailScreen> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  bool _isAdmin = false;
  bool _isLoadingRole = true;
  bool _isUpdating = false;

  late OutageReport _report;

  @override
  void initState() {
    super.initState();
    _report = widget.report;
    _loadUserRole();
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

    setState(() => _isUpdating = true);
    await _firestoreService.confirmOutage(_report.id, uid);

    setState(() {
      _report = OutageReport(
        id: _report.id,
        reporterId: _report.reporterId,
        area: _report.area,
        latitude: _report.latitude,
        longitude: _report.longitude,
        startTime: _report.startTime,
        endTime: _report.endTime,
        status: _report.status,
        severity: _report.severity,
        outageType: _report.outageType,
        estimatedRestoration: _report.estimatedRestoration,
        description: _report.description,
        confirmedByUserIds: [..._report.confirmedByUserIds, uid],
        verified: _report.verified,
        createdAt: _report.createdAt,
      );
      _isUpdating = false;
    });
  }

  Future<void> _markAsRestored() async {
    setState(() => _isUpdating = true);

    await _firestoreService.updateReport(_report.id, {
      'status': OutageStatus.restored.name,
      'endTime': Timestamp.now(),
    });

    // Notify everyone who confirmed this outage that it's now restored.
    for (final uid in _report.confirmedByUserIds) {
      if (uid == _authService.currentUser?.uid) continue;
      await _firestoreService.createNotification(
        userId: uid,
        type: NotificationType.powerRestored,
        title: 'Power Restored',
        message: '${_report.area} has been marked as restored.',
        relatedReportId: _report.id,
      );
    }

    setState(() {
      _report = OutageReport(
        id: _report.id,
        reporterId: _report.reporterId,
        area: _report.area,
        latitude: _report.latitude,
        longitude: _report.longitude,
        startTime: _report.startTime,
        endTime: DateTime.now(),
        status: OutageStatus.restored,
        severity: _report.severity,
        outageType: _report.outageType,
        estimatedRestoration: _report.estimatedRestoration,
        description: _report.description,
        confirmedByUserIds: _report.confirmedByUserIds,
        verified: _report.verified,
        createdAt: _report.createdAt,
      );
      _isUpdating = false;
    });

    if (mounted) {
      AppSnackbar.show(
        context,
        message: 'Marked as restored',
        type: AppMessageType.info,
      );
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
                              Text(
                                _report.severity.name[0].toUpperCase() +
                                    _report.severity.name.substring(1),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
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
                              Text(
                                outageTypeLabel(_report.outageType),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
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
                      Icon(
                        Icons.description_outlined,
                        size: 16,
                        color: Colors.grey[500],
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

                  // MAP PREVIEW
                  if (_report.latitude != 0.0 && _report.longitude != 0.0)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        height: 120,
                        child: IgnorePointer(
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

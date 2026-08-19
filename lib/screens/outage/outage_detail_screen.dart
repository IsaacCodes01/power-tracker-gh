import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../models/outage_report.dart';

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

  late OutageReport _report; // Local copy so we can update it live on screen.

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
        estimatedRestoration: _report.estimatedRestoration,
        description: _report.description,
        confirmedByUserIds: _report.confirmedByUserIds,
        verified: _report.verified,
        createdAt: _report.createdAt,
      );
      _isUpdating = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Marked as restored ✓')));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(_report.area),
        backgroundColor: Colors.grey[100],
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // STATUS BADGE
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _statusColor(_report.status).withAlpha(30),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _report.status.name.toUpperCase(),
                style: TextStyle(
                  color: _statusColor(_report.status),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),

            _infoRow('Severity', _report.severity.name),
            _infoRow('Reported', _report.startTime.toString()),
            if (_report.endTime != null)
              _infoRow('Restored', _report.endTime.toString()),
            const SizedBox(height: 12),

            const Text(
              'Description',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(_report.description),
            const SizedBox(height: 24),

            // CONFIRM BUTTON
            OutlinedButton.icon(
              onPressed: (_isUpdating || _hasConfirmed) ? null : _confirmOutage,
              icon: const Icon(Icons.people),
              label: Text(
                _hasConfirmed
                    ? 'You confirmed this (${_report.confirmedByUserIds.length} total)'
                    : 'I\'m also affected (${_report.confirmedByUserIds.length})',
              ),
            ),
            const SizedBox(height: 12),

            // MARK AS RESTORED — only visible to reporter or admin
            if (!_isLoadingRole &&
                _canMarkRestored &&
                _report.status != OutageStatus.restored)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isUpdating ? null : _markAsRestored,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Mark as Restored'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

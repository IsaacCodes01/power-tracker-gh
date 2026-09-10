import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../../models/outage_report.dart';
import '../../widgets/app_snackbar.dart';
import '../../models/notification_item.dart';

class AdminReportDetailScreen extends StatefulWidget {
  final OutageReport report;

  const AdminReportDetailScreen({super.key, required this.report});

  @override
  State<AdminReportDetailScreen> createState() =>
      _AdminReportDetailScreenState();
}

class _AdminReportDetailScreenState extends State<AdminReportDetailScreen> {
  final _firestoreService = FirestoreService();
  late OutageReport _report;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _report = widget.report;
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

  Future<void> _changeStatus(OutageStatus newStatus) async {
    if (_report.status == newStatus) return;
    setState(() => _isUpdating = true);

    try {
      await _firestoreService.updateReport(_report.id, {
        'status': newStatus.name,
        if (newStatus == OutageStatus.restored) 'endTime': Timestamp.now(),
      });

      // Only notify for genuine forward progress: investigating, repairing, restored.
      final notifiableStatuses = {
        OutageStatus.investigating,
        OutageStatus.repairing,
        OutageStatus.restored,
      };

      if (notifiableStatuses.contains(newStatus)) {
        final isRestored = newStatus == OutageStatus.restored;

        // Notify the reporter, plus everyone who confirmed the outage.
        final recipientIds = {
          _report.reporterId,
          ..._report.confirmedByUserIds,
        };

        for (final uid in recipientIds) {
          await _firestoreService.createNotification(
            userId: uid,
            type: isRestored
                ? NotificationType.powerRestored
                : NotificationType.statusUpdate,
            title: isRestored ? 'Power Restored' : 'Status Update',
            message: isRestored
                ? 'Good news! Power for ${_report.area} has been restored.'
                : 'Your report for ${_report.area} is now ${_statusLabel(newStatus)}.',
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
            endTime: isRestored ? DateTime.now() : _report.endTime,
            status: newStatus,
            severity: _report.severity,
            outageType: _report.outageType,
            estimatedRestoration: _report.estimatedRestoration,
            description: _report.description,
            confirmedByUserIds: _report.confirmedByUserIds,
            verified: _report.verified,
            createdAt: _report.createdAt,
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
        AppSnackbar.show(
          context,
          message: 'Status updated to ${_statusLabel(newStatus)}',
          type: AppMessageType.success,
        );
      }
    }
  }

  Future<void> _toggleVerify() async {
    if (_report.verified) return;
    setState(() => _isUpdating = true);

    try {
      await _firestoreService.verifyReport(_report.id);

      await _firestoreService.createNotification(
        userId: _report.reporterId,
        type: NotificationType.reportVerified,
        title: 'Report Verified',
        message: 'Your report for ${_report.area} has been verified.',
        relatedReportId: _report.id,
      );

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
          confirmedByUserIds: _report.confirmedByUserIds,
          verified: true,
          createdAt: _report.createdAt,
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
        AppSnackbar.show(
          context,
          message: 'Report verified',
          type: AppMessageType.success,
        );
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Report?'),
        content: Text(
          'This will permanently delete the report for "${_report.area}". This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _firestoreService.deleteReport(_report.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(_report.area),
        backgroundColor: Colors.deepPurple[900],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        outageTypeIcon(_report.outageType),
                        size: 16,
                        color: Colors.deepPurple,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Outage Type: ${outageTypeLabel(_report.outageType)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: severityColor(_report.severity),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Severity: ${_report.severity.name}',
                        style: TextStyle(
                          color: severityColor(_report.severity),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.description_outlined,
                        size: 16,
                        color: Colors.black,
                      ),
                      const SizedBox(width: 6),
                      Expanded(child: Text(_report.description)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 16,
                        color: Colors.pink[600],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Confirmed by ${_report.confirmedByUserIds.length} user(s)',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            const Text('Status', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<OutageStatus>(
              initialValue: _report.status,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: OutageStatus.values.map((status) {
                return DropdownMenuItem(
                  value: status,
                  child: Text(_statusLabel(status)),
                );
              }).toList(),
              onChanged: _isUpdating
                  ? null
                  : (value) {
                      if (value != null) _changeStatus(value);
                    },
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: (_isUpdating || _report.verified)
                    ? null
                    : _toggleVerify,
                icon: Icon(
                  _report.verified
                      ? Icons.verified
                      : Icons.check_circle_outline,
                  color: _report.verified ? Colors.green : Colors.grey,
                ),
                label: Text(_report.verified ? 'Verified' : 'Verify Report'),
              ),
            ),
            const SizedBox(height: 10),

            // Placeholder — full response feature pending teammate's spec.
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  AppSnackbar.show(
                    context,
                    message: 'Send Response — coming soon',
                    type: AppMessageType.info,
                  );
                },
                icon: const Icon(Icons.reply),
                label: const Text('Send Response'),
              ),
            ),
            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _confirmDelete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[400],
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete Report'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

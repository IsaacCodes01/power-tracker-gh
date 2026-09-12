import 'package:flutter/material.dart';
import '../../models/notification_item.dart';
import '../../services/firestore_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/notification_style.dart';
import '../outage/outage_detail_screen.dart';

class NotificationDetailScreen extends StatefulWidget {
  final NotificationItem notification;

  const NotificationDetailScreen({super.key, required this.notification});

  @override
  State<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  final _firestoreService = FirestoreService();
  bool _isLoadingReport = false;

  Future<void> _openRelatedReport() async {
    final reportId = widget.notification.relatedReportId;
    if (reportId == null) return;

    setState(() => _isLoadingReport = true);
    try {
      final report = await _firestoreService.getReport(reportId);
      if (!mounted) return;
      if (report == null) {
        AppSnackbar.show(
          context,
          message: 'This report no longer exists.',
          type: AppMessageType.error,
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OutageDetailScreen(report: report)),
      );
    } catch (_) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Unable to open the report right now.',
          type: AppMessageType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingReport = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notification = widget.notification;
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 10),
            CircleAvatar(
              radius: 20,
              backgroundColor: notificationTypeColor(
                notification.type,
              ).withAlpha(30),
              child: Icon(
                notificationTypeIcon(notification.type),
                color: notificationTypeColor(notification.type),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              notification.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              '${notification.createdAt.toLocal()}'.split('.').first,
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            const SizedBox(height: 24),
            Text(
              notification.message,
              textAlign: TextAlign.left,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
            // Lets someone jump straight from a notification (e.g.
            // "Power Restored") to that exact report — this is also
            // where the "is your light really back?" check lives, since
            // it's shown on the report screen itself.
            if (notification.relatedReportId != null) ...[
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _isLoadingReport ? null : _openRelatedReport,
                  icon: _isLoadingReport
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.description_outlined, size: 18),
                  label: const Text('View Report'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../models/notification_item.dart';
import '../../widgets/notification_style.dart';

class NotificationDetailScreen extends StatelessWidget {
  final NotificationItem notification;

  const NotificationDetailScreen({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
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
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../models/notification_item.dart';

IconData notificationTypeIcon(NotificationType type) {
  switch (type) {
    case NotificationType.reportVerified:
      return Icons.verified;
    case NotificationType.powerRestored:
      return Icons.bolt;
    case NotificationType.statusUpdate:
      return Icons.sync;
    case NotificationType.announcement:
      return Icons.campaign;
    case NotificationType.maintenance:
      return Icons.build_circle;
    case NotificationType.newReport:
      return Icons.assignment;
  }
}

Color notificationTypeColor(NotificationType type) {
  switch (type) {
    case NotificationType.reportVerified:
      return Colors.green;
    case NotificationType.powerRestored:
      return Colors.blue;
    case NotificationType.statusUpdate:
      return Colors.orange;
    case NotificationType.announcement:
      return Colors.deepPurple;
    case NotificationType.maintenance:
      return Colors.red;
    case NotificationType.newReport:
      return Colors.indigo;
  }
}

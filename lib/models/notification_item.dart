import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  reportVerified,
  powerRestored,
  statusUpdate,
  announcement,
  maintenance,
  newReport,
}

class NotificationItem {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String message;
  final bool read;
  final String? relatedReportId;
  final DateTime createdAt;

  NotificationItem({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.read = false,
    this.relatedReportId,
    required this.createdAt,
  });

  factory NotificationItem.fromMap(String id, Map<String, dynamic> data) {
    return NotificationItem(
      id: id,
      userId: data['userId'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => NotificationType.announcement,
      ),
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      read: data['read'] ?? false,
      relatedReportId: data['relatedReportId'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type.name,
      'title': title,
      'message': message,
      'read': read,
      'relatedReportId': relatedReportId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

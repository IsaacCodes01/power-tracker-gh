import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/outage_report.dart';
import '../models/app_user.dart'; // ADDED: Import your user model
import '../models/notification_item.dart';

class FirestoreService {
  final CollectionReference _reportsRef = FirebaseFirestore.instance.collection(
    'outage_reports',
  );

  // CREATE: files a new form into the cabinet.
  Future<void> createReport(OutageReport report) async {
    await _reportsRef.add(report.toMap());
  }

  // Writes a new notification for a specific user.
  Future<void> createNotification({
    required String userId,
    required String title,
    required String message,
    String? relatedReportId,
  }) async {
    await _notificationsRef.add({
      'userId': userId,
      'title': title,
      'message': message,
      'read': false,
      'relatedReportId': relatedReportId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Live list of one user's notifications, newest first.
  Stream<List<NotificationItem>> streamNotifications(String userId) {
    return _notificationsRef
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => NotificationItem.fromMap(
                  doc.id,
                  doc.data() as Map<String, dynamic>,
                ),
              )
              .toList(),
        );
  }

  // Live count of unread notifications, used for the red badge.
  Stream<int> streamUnreadCount(String userId) {
    return _notificationsRef
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _notificationsRef.doc(notificationId).update({'read': true});
  }

  final CollectionReference _notificationsRef = FirebaseFirestore.instance
      .collection('notifications');

  // READ (live list): keeps watching the cabinet and hands back
  // an updated list automatically whenever anything changes.
  Stream<List<OutageReport>> streamReports() {
    return _reportsRef
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => OutageReport.fromMap(
                  doc.id,
                  doc.data() as Map<String, dynamic>,
                ),
              )
              .toList(),
        );
  }

  // READ (single report): pulls out one specific form by its ID.
  Future<OutageReport?> getReport(String reportId) async {
    final doc = await _reportsRef.doc(reportId).get();
    if (!doc.exists) return null;
    return OutageReport.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }

  // UPDATE: edits specific boxes on an existing form, leaving the rest alone.
  Future<void> updateReport(
    String reportId,
    Map<String, dynamic> updates,
  ) async {
    await _reportsRef.doc(reportId).update(updates);
  }

  // DELETE: removes a form from the cabinet entirely.
  Future<void> deleteReport(String reportId) async {
    await _reportsRef.doc(reportId).delete();
  }

  // "I'm also affected" — adds this user's ID to the confirmation list,
  // but only if they haven't already confirmed (no duplicates).
  Future<void> confirmOutage(String reportId, String userId) async {
    await _reportsRef.doc(reportId).update({
      'confirmedByUserIds': FieldValue.arrayUnion([userId]),
    });
  }

  // Admin-only: stamps a report as officially verified.
  Future<void> verifyReport(String reportId) async {
    await _reportsRef.doc(reportId).update({'verified': true});
  }

  final CollectionReference _usersRef = FirebaseFirestore.instance.collection(
    'users',
  );

  // Looks up initials (first letter of email) for a list of user IDs,
  // used to show small avatar bubbles on report cards.
  Future<List<String>> getUserInitials(List<String> uids) async {
    if (uids.isEmpty) return [];

    final snapshot = await _usersRef
        .where(FieldPath.documentId, whereIn: uids.take(10).toList())
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final email = data['email'] as String? ?? '?';
      return email.substring(0, 1).toUpperCase();
    }).toList();
  }

  // ==========================================
  //            USER PROFILE METHODS
  // ==========================================

  // READ USER: Fetches a single user profile from Firestore mapping it directly to AppUser
  Future<AppUser?> getUserProfile(String uid) async {
    try {
      final doc = await _usersRef.doc(uid).get();
      if (!doc.exists || doc.data() == null) return null;
      return AppUser.fromMap(doc.data() as Map<String, dynamic>);
    } catch (e) {
      debugPrint("Error fetching user profile: $e");
      return null;
    }
  }

  // UPDATE USER: Modifies targeted user data fields (like phone number) safely
  Future<void> updateUserProfile(
    String uid,
    Map<String, dynamic> updates,
  ) async {
    await _usersRef.doc(uid).update(updates);
  }

  // ==========================================
  //          DEFAULT USER LOCATION METHODS
  // ==========================================

  // Saves a user's chosen default location coordinates to their profile document
  Future<void> saveDefaultLocation(
    String uid,
    double lat,
    double lon,
    String locationName,
  ) async {
    await _usersRef.doc(uid).update({
      'defaultLatitude': lat,
      'defaultLongitude': lon,
      'defaultLocationName': locationName,
    });
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/outage_report.dart';
import '../models/app_user.dart';
import '../models/notification_item.dart';
import '../utils/network_guard.dart';

class FirestoreService {
  final CollectionReference _reportsRef = FirebaseFirestore.instance.collection(
    'outage_reports',
  );

  // CREATE: files a new form into the cabinet.
  Future<void> createReport(OutageReport report) async {
    await _reportsRef.add(report.toMap()).withNetworkTimeout();
  }

  Future<void> updateNotificationPreferences(
    String uid,
    Map<String, bool> prefs,
  ) async {
    await _usersRef.doc(uid).update(prefs);
  }

  // ==========================================
  //          PUSH NOTIFICATION (FCM) METHODS
  // ==========================================

  // Saves this device's FCM token to the user's profile so the
  // sendPushOnNotification Cloud Function knows where to deliver pushes.
  // Safe to call repeatedly (e.g. on every app start / token refresh) —
  // just overwrites with whatever the current token is.
  Future<void> saveFcmToken(String uid, String token) async {
    await _usersRef.doc(uid).update({'fcmToken': token});
  }

  // Called on sign-out so a logged-out device stops receiving pushes
  // meant for whoever's account it's signed into next.
  Future<void> clearFcmToken(String uid) async {
    await _usersRef.doc(uid).update({'fcmToken': FieldValue.delete()});
  }

  // Writes a new notification for a specific user.
  Future<void> createNotification({
    required String userId,
    required NotificationType type,
    required String title,
    required String message,
    String? relatedReportId,
  }) async {
    final profile = await getUserProfile(userId);
    if (profile != null) {
      final allowed = switch (type) {
        NotificationType.reportVerified => profile.notifyVerification,
        NotificationType.powerRestored => profile.notifyPowerRestored,
        NotificationType.statusUpdate => profile.notifyStatusUpdates,
        NotificationType.announcement => profile.notifyAnnouncements,
        NotificationType.maintenance => profile.notifyMaintenance,
        // Admins don't have a dedicated toggle for this — it's an
        // operational "you have work to do" notification, not a
        // discretionary broadcast, so it's always on.
        NotificationType.newReport => true,
      };
      if (!allowed) return;

      await _notificationsRef.add({
        'userId': userId,
        'type': type.name,
        'title': title,
        'message': message,
        'read': false,
        'relatedReportId': relatedReportId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
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

  Stream<int> streamUserCount() {
    return _usersRef.snapshots().map((snapshot) => snapshot.docs.length);
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

  Future<void> markAllNotificationsRead(String userId) async {
    final snapshot = await _notificationsRef
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();

    for (final doc in snapshot.docs) {
      await doc.reference.update({'read': true});
    }
  }

  final CollectionReference _notificationsRef = FirebaseFirestore.instance
      .collection('notifications');

  // READ (live list): keeps watching the cabinet and hands back
  // an updated list automatically whenever anything changes.
  // READ (live list): keeps watching the cabinet and hands back
  // an updated list automatically whenever anything changes.
  Stream<List<OutageReport>> streamReports() {
    return _reportsRef
        .orderBy('createdAt', descending: true)
        .limit(500) // was 100, now 500 to avoid crowding
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => OutageReport.fromMap(
                  doc.id,
                  doc.data() as Map<String, dynamic>,
                ),
              )
              .where(_isVisibleInFeed)
              .take(100)
              .toList(),
        );
  }

  // FOR ADMINS: Admin panel uses this - sees ALL reports, no filter
  Stream<List<OutageReport>> streamReportsForAdmin() {
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

  // NEW: A resolved report stays visible for 48h after endTime, then
  // drops out of the feed. It is never deleted — admin/history views
  // that bypass this stream still see everything.
  bool _isVisibleInFeed(OutageReport report) {
    if (report.status != OutageStatus.restored) return true;
    if (report.endTime == null) {
      return true; // safety fallback, don't hide bad data
    }
    final hoursSinceResolved = DateTime.now()
        .difference(report.endTime!)
        .inHours;
    return hoursSinceResolved < 48;
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

  Future<void> setAdminPin(String uid, String pin) async {
    await _usersRef.doc(uid).update({'adminPin': pin});
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

  Future<List<String>> getAdminUserIds() async {
    final snapshot = await _usersRef.where('role', isEqualTo: 'admin').get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  // Fetches every registered user's ID, used for broadcasting an
  // announcement to all users rather than a specific area.
  Future<List<String>> getAllUserIds() async {
    final snapshot = await _usersRef.get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  // Returns every distinct area name that has at least one report,
  // used to populate the area picker in Send Announcements.
  Future<List<String>> getDistinctAreas() async {
    final snapshot = await _reportsRef.get();
    final areas = snapshot.docs
        .map(
          (doc) =>
              (doc.data() as Map<String, dynamic>)['area'] as String? ?? '',
        )
        .where((area) => area.isNotEmpty)
        .toSet()
        .toList();
    areas.sort();
    return areas;
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

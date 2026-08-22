import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/outage_report.dart';
import '../models/app_user.dart'; // ADDED: Import your user model

class FirestoreService {
  final CollectionReference _reportsRef = FirebaseFirestore.instance.collection(
    'outage_reports',
  );

  // ADDED: Reference to the users collection in your database
  final CollectionReference _usersRef = FirebaseFirestore.instance.collection(
    'users',
  );

  // CREATE: files a new form into the cabinet.
  Future<void> createReport(OutageReport report) async {
    await _reportsRef.add(report.toMap());
  }

  // READ (live list): keeps watching the cabinet and hands back
  // an updated list automatically whenever anything changes.
  Stream<List<OutageReport>> streamReports() {
    return _reportsRef
        .orderBy('createdAt', descending: true)
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
}

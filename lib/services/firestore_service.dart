import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/outage_report.dart';

class FirestoreService {
  final CollectionReference _reportsRef =
  FirebaseFirestore.instance.collection('outage_reports');

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
        .map((snapshot) => snapshot.docs
        .map((doc) => OutageReport.fromMap(
        doc.id, doc.data() as Map<String, dynamic>))
        .toList());
  }

  // READ (single report): pulls out one specific form by its ID.
  Future<OutageReport?> getReport(String reportId) async {
    final doc = await _reportsRef.doc(reportId).get();
    if (!doc.exists) return null;
    return OutageReport.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }

  // UPDATE: edits specific boxes on an existing form, leaving the rest alone.
  Future<void> updateReport(String reportId, Map<String, dynamic> updates) async {
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
}
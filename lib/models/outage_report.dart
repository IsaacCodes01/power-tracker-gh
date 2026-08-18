import 'package:cloud_firestore/cloud_firestore.dart';

enum OutageStatus { reported, investigating, repairing, restored }
enum OutageSeverity { minor, moderate, major }

class OutageReport {
  final String id;
  final String reporterId;
  final String area;
  final double latitude;
  final double longitude;
  final DateTime startTime;
  final DateTime? endTime;
  final OutageStatus status;
  final OutageSeverity severity;
  final DateTime? estimatedRestoration;
  final String description;
  final List<String> confirmedByUserIds;
  final bool verified;
  final DateTime createdAt;

  OutageReport({
    required this.id,
    required this.reporterId,
    required this.area,
    required this.latitude,
    required this.longitude,
    required this.startTime,
    this.endTime,
    required this.status,
    required this.severity,
    this.estimatedRestoration,
    required this.description,
    this.confirmedByUserIds = const [],
    this.verified = false,
    required this.createdAt,
  });

  // Converts a Firestore document into an OutageReport object.
  factory OutageReport.fromMap(String id, Map<String, dynamic> data) {
    return OutageReport(
      id: id,
      reporterId: data['reporterId'] ?? '',
      area: data['area'] ?? '',
      latitude: (data['latitude'] ?? 0).toDouble(),
      longitude: (data['longitude'] ?? 0).toDouble(),
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: data['endTime'] != null
          ? (data['endTime'] as Timestamp).toDate()
          : null,
      status: OutageStatus.values.firstWhere(
            (e) => e.name == data['status'],
        orElse: () => OutageStatus.reported,
      ),
      severity: OutageSeverity.values.firstWhere(
            (e) => e.name == data['severity'],
        orElse: () => OutageSeverity.minor,
      ),
      estimatedRestoration: data['estimatedRestoration'] != null
          ? (data['estimatedRestoration'] as Timestamp).toDate()
          : null,
      description: data['description'] ?? '',
      confirmedByUserIds: List<String>.from(data['confirmedByUserIds'] ?? []),
      verified: data['verified'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  // Converts this object into a Map for saving to Firestore.
  Map<String, dynamic> toMap() {
    return {
      'reporterId': reporterId,
      'area': area,
      'latitude': latitude,
      'longitude': longitude,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'status': status.name,
      'severity': severity.name,
      'estimatedRestoration': estimatedRestoration != null
          ? Timestamp.fromDate(estimatedRestoration!)
          : null,
      'description': description,
      'confirmedByUserIds': confirmedByUserIds,
      'verified': verified,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
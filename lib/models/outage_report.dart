import 'package:cloud_firestore/cloud_firestore.dart';

enum OutageStatus { reported, investigating, repairing, restored }

enum OutageSeverity { minor, moderate, major }

enum OutageType { powerOutage, flickeringLights, voltageFluctuation, poleFault }

String outageTypeLabel(OutageType type) {
  switch (type) {
    case OutageType.powerOutage:
      return 'Power Outage';
    case OutageType.flickeringLights:
      return 'Flickering Lights';
    case OutageType.voltageFluctuation:
      return 'Voltage Fluctuation';
    case OutageType.poleFault:
      return 'Pole Fault';
  }
}

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
  final OutageType outageType;
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
    required this.outageType,
    this.estimatedRestoration,
    required this.description,
    this.confirmedByUserIds = const [],
    this.verified = false,
    required this.createdAt,
  });

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
      outageType: OutageType.values.firstWhere(
        (e) => e.name == data['outageType'],
        orElse: () => OutageType.powerOutage,
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
      'outageType': outageType.name,
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

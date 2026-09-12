import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

// Shared with OutageCard/AdminReportCard so every screen shows the same
// icon for a given outage type instead of each screen picking its own.
IconData outageTypeIcon(OutageType type) {
  switch (type) {
    case OutageType.powerOutage:
      return Icons.power_off;
    case OutageType.flickeringLights:
      return Icons.lightbulb_outline;
    case OutageType.voltageFluctuation:
      return Icons.bolt;
    case OutageType.poleFault:
      return Icons.report_problem_outlined;
  }
}

// Shared per-type accent color, used anywhere an outage type gets its own
// badge or icon tint (admin overview tiles, filter chips, etc).
Color outageTypeColor(OutageType type) {
  switch (type) {
    case OutageType.powerOutage:
      return Colors.redAccent;
    case OutageType.flickeringLights:
      return Colors.amber[800]!;
    case OutageType.voltageFluctuation:
      return Colors.blue;
    case OutageType.poleFault:
      return Colors.deepOrange;
  }
}

// Severity color scale used anywhere severity needs an icon/badge —
// escalates from calm to urgent the same way status colors do.
Color severityColor(OutageSeverity severity) {
  switch (severity) {
    case OutageSeverity.minor:
      return Colors.blue;
    case OutageSeverity.moderate:
      return Colors.orange;
    case OutageSeverity.major:
      return Colors.redAccent;
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

  // Confirmers who've already answered "is your light really back?" after
  // this report was marked restored — regardless of which way they
  // answered. Stops the prompt from being shown to them again once
  // they've responded once.
  final List<String> restorationCheckRespondedUserIds;

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
    this.restorationCheckRespondedUserIds = const [],
  });

  // Returns a copy with only the given fields changed — everything else
  // carries over automatically from the original. Safer than manually
  // rebuilding the object field-by-field: a new field added to this
  // class later is picked up here for free, instead of silently being
  // missed in every hand-written copy scattered across the app.
  OutageReport copyWith({
    OutageStatus? status,
    DateTime? endTime,
    List<String>? confirmedByUserIds,
    bool? verified,
    List<String>? restorationCheckRespondedUserIds,
  }) {
    return OutageReport(
      id: id,
      reporterId: reporterId,
      area: area,
      latitude: latitude,
      longitude: longitude,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      severity: severity,
      outageType: outageType,
      estimatedRestoration: estimatedRestoration,
      description: description,
      confirmedByUserIds: confirmedByUserIds ?? this.confirmedByUserIds,
      verified: verified ?? this.verified,
      createdAt: createdAt,
      restorationCheckRespondedUserIds:
          restorationCheckRespondedUserIds ??
          this.restorationCheckRespondedUserIds,
    );
  }

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
      restorationCheckRespondedUserIds: List<String>.from(
        data['restorationCheckRespondedUserIds'] ?? [],
      ),
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
      'restorationCheckRespondedUserIds': restorationCheckRespondedUserIds,
    };
  }
}

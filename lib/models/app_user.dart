import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String email;
  final String role;
  final List<String> savedAreas;
  final double? defaultLatitude;
  final double? defaultLongitude;
  final String? defaultLocationName;
  final String? adminPin;
  final DateTime createdAt;
  final bool notifyPowerRestored;
  final bool notifyStatusUpdates;
  final bool notifyVerification;
  final bool notifyAnnouncements;
  final bool notifyMaintenance;

  // ADDED: The new optional phoneNumber property
  final String phoneNumber;

  // ADDED: Full name + derived first name, used for greetings and display.
  final String fullName;
  final String firstName;

  AppUser({
    required this.uid,
    required this.email,
    required this.role,
    this.adminPin,
    this.savedAreas = const [],
    this.defaultLatitude,
    this.defaultLongitude,
    this.defaultLocationName,
    required this.createdAt,
    this.phoneNumber = '', // Default to an empty string if not provided
    this.fullName = '',
    this.firstName = '',
    required this.notifyAnnouncements,
    required this.notifyStatusUpdates,
    required this.notifyVerification,
    required this.notifyMaintenance,
    required this.notifyPowerRestored,
  });

  // Converts a Firestore document into an AppUser object.
  factory AppUser.fromMap(Map<String, dynamic> data) {
    return AppUser(
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'user',
      adminPin: data['adminPin'],
      savedAreas: List<String>.from(data['savedAreas'] ?? []),
      defaultLatitude: (data['defaultLatitude'] as num?)?.toDouble(),
      defaultLongitude: (data['defaultLongitude'] as num?)?.toDouble(),
      defaultLocationName: data['defaultLocationName'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      // FIXED: Safely reads the phoneNumber from the Firestore document payload
      phoneNumber: data['phoneNumber'] ?? '',
      // ADDED: Safely reads fullName/firstName; older accounts created before
      // this field existed will just fall back to empty strings.
      fullName: data['fullName'] ?? '',
      firstName: data['firstName'] ?? '',
      notifyAnnouncements: data['notifyAnnouncements'] ?? true,
      notifyStatusUpdates: data['notifyStatusUpdates'] ?? true,
      notifyVerification: data['notifyVerification'] ?? true,
      notifyMaintenance: data['notifyMaintenance'] ?? true,
      notifyPowerRestored: data['notifyPowerRestored'] ?? true,
    );
  }

  // Converts this object into a Map for saving to Firestore.
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'role': role,
      'adminPin': adminPin,
      'savedAreas': savedAreas,
      'defaultLatitude': defaultLatitude,
      'defaultLongitude': defaultLongitude,
      'defaultLocationName': defaultLocationName,
      'createdAt': Timestamp.fromDate(createdAt),
      // FIXED: Packs the phone number string into your database upload map
      'phoneNumber': phoneNumber,
      // ADDED: persist fullName/firstName alongside everything else
      'fullName': fullName,
      'firstName': firstName,
      'notifyAnnouncements': notifyAnnouncements,
      'notifyStatusUpdates': notifyStatusUpdates,
      'notifyVerification': notifyVerification,
      'notifyMaintenance': notifyMaintenance,
      'notifyPowerRestored': notifyPowerRestored,
    };
  }

  bool get isAdmin => role == 'admin';

  // True once the user has genuinely set a default location at least once.
  bool get hasDefaultLocation =>
      defaultLatitude != null && defaultLongitude != null;

  // ADDED: Best available first name for greetings. Falls back gracefully
  // for accounts created before fullName/firstName existed.
  String get greetingName {
    if (firstName.isNotEmpty) return firstName;
    if (fullName.trim().isNotEmpty) return fullName.trim().split(' ').first;
    if (email.contains('@')) return email.split('@').first;
    return '';
  }

  // ADDED: Role label shown under the user's name in Settings.
  String get roleLabel =>
      isAdmin ? 'Power Tracker admin' : 'Power Tracker user';
}

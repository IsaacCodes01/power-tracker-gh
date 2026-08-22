import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String email;
  final String role;
  final List<String> savedAreas;
  final DateTime createdAt;

  // ADDED: The new optional phoneNumber property
  final String phoneNumber;

  AppUser({
    required this.uid,
    required this.email,
    required this.role,
    this.savedAreas = const [],
    required this.createdAt,
    this.phoneNumber = '', // Default to an empty string if not provided
  });

  // Converts a Firestore document into an AppUser object.
  factory AppUser.fromMap(Map<String, dynamic> data) {
    return AppUser(
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'user',
      savedAreas: List<String>.from(data['savedAreas'] ?? []),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      // FIXED: Safely reads the phoneNumber from the Firestore document payload
      phoneNumber: data['phoneNumber'] ?? '',
    );
  }

  // Converts this object into a Map for saving to Firestore.
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'role': role,
      'savedAreas': savedAreas,
      'createdAt': Timestamp.fromDate(createdAt),
      // FIXED: Packs the phone number string into your database upload map
      'phoneNumber': phoneNumber,
    };
  }

  bool get isAdmin => role == 'admin';
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Returns the currently signed-in user, or null if nobody's logged in.
  User? get currentUser => _auth.currentUser;

  // Listens for auth state changes (logged in / logged out) in real time.
  // Screens can watch this to auto-redirect between login and home.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // SIGN UP: creates the account in Firebase Auth, then creates a matching
  // user profile document in Firestore with role hardcoded to "user".
  Future<User?> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        // Every new signup is a regular user, no exceptions.
        // We catch errors locally here so a Firestore failure won't crash the Auth process!
        try {
          await _firestore.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'email': email,
            'role': 'user',
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (databaseError) {
          // Log the error to your terminal console so you know about it,
          // but allow the function to continue so the user account is preserved.
          debugPrint("⚠️ Firestore profile creation failed: $databaseError");
        }
      }

      return user;
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    } catch (generalError) {
      // Catches any non-Auth exceptions (like database issues) and passes a clean string
      throw 'Account registered with warnings. Please try logging in.';
    }
  }

  // SIGN IN
  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  // SIGN OUT
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // PASSWORD RESET: sends a reset link to the user's email via Firebase.
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  // Fetches the user's role ("user" or "admin") from Firestore.
  // Screens use this to decide whether to show admin-only options.
  Future<String> getUserRole(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return doc.data()!['role'] ?? 'user';
    }
    return 'user';
  }

  // Add these two methods inside your AuthService class

  Future<void> updateEmail(String newEmail) async {
    try {
      await _auth.currentUser?.verifyBeforeUpdateEmail(newEmail);
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  Future<void> deleteAccount() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        await _firestore.collection('users').doc(uid).delete();
      }
      await _auth.currentUser?.delete();
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  Future<void> reauthenticate(String password) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw 'No user currently signed in.';
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  // Converts Firebase's technical error codes into messages a user
  // would actually understand, instead of raw error strings.
  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}

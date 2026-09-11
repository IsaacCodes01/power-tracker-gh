import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
import '../utils/network_guard.dart';

// Thrown by signInWithGoogle() when the Google email already belongs to
// an account created with a different sign-in method (almost always
// email/password here). Carries what's needed to let the UI prompt for
// that password and link the two accounts together.
class AccountExistsException implements Exception {
  final String email;
  final AuthCredential pendingCredential;

  AccountExistsException({
    required this.email,
    required this.pendingCredential,
  });
}

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
  // UPDATED: Added the optional phoneNumber argument here.
  // ADDED: fullName is now required so we can greet the user by first name
  // and show their name in Settings.
  Future<User?> signUp({
    required String fullName,
    required String email,
    required String password,
    String? phoneNumber,
  }) async {
    try {
      final credential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password)
          .withNetworkTimeout();

      final user = credential.user;
      if (user != null) {
        final trimmedFullName = fullName.trim();
        final firstName = trimmedFullName.isNotEmpty
            ? trimmedFullName.split(' ').first
            : '';

        // ADDED: keep Firebase Auth's own displayName in sync too, so it
        // shows up consistently anywhere Firebase surfaces it natively.
        try {
          await user.updateDisplayName(trimmedFullName);
        } catch (displayNameError) {
          debugPrint("⚠️ updateDisplayName failed: $displayNameError");
        }

        // ADDED: send Firebase's built-in verification email right away,
        // using its default template — no custom email service needed.
        try {
          await user.sendEmailVerification();
        } catch (verificationError) {
          debugPrint("⚠️ sendEmailVerification failed: $verificationError");
        }

        // Every new signup is a regular user, no exceptions.
        // We catch errors locally here so a Firestore failure won't crash the Auth process!
        try {
          await _firestore.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'email': email,
            'role': 'user',
            'createdAt': FieldValue.serverTimestamp(),
            // FIXED: Safely logs the phone number field or defaults to an empty string
            'phoneNumber': phoneNumber ?? '',
            // ADDED: full name + derived first name for greetings
            'fullName': trimmedFullName,
            'firstName': firstName,
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
      final credential = await _auth
          .signInWithEmailAndPassword(email: email, password: password)
          .withNetworkTimeout();
      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  // SIGN OUT
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ADDED: resend the verification email while the user is currently
  // signed in (e.g. right after login, before we've signed them back out).
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw 'No signed-in user. Please log in again to resend.';
    }
    if (user.emailVerified) {
      throw 'Your email is already verified.';
    }
    await user.sendEmailVerification().withNetworkTimeout();
  }

  // ADDED: resend the verification email when the user is signed OUT —
  // needs their email/password to sign in briefly, send, then sign back out.
  Future<void> resendVerificationAfterLogout({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = cred.user;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }
      await _auth.signOut();
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  // ADDED: forces Firebase to refresh the user's token/data so
  // emailVerified reflects whether they clicked the link yet.
  Future<bool> reloadAndCheckVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload().withNetworkTimeout();
    return _auth.currentUser?.emailVerified ?? false;
  }

  // PASSWORD RESET: sends a reset link to the user's email via Firebase.
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email).withNetworkTimeout();
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
      case 'network-request-failed':
        return const NetworkUnavailableException().toString();
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      // For google_sign_in ^7.0.0
      await GoogleSignIn.instance.initialize();

      final GoogleSignInAccount googleUser = await GoogleSignIn.instance
          .authenticate();

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) throw 'No ID Token found';

      final credential = GoogleAuthProvider.credential(idToken: idToken);

      UserCredential userCred;
      try {
        userCred = await _auth
            .signInWithCredential(credential)
            .withNetworkTimeout();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'account-exists-with-different-credential') {
          // Same email already has an account under a different provider
          // (e.g. email/password signup). Hand the pending Google
          // credential up to the UI so it can ask for that password and
          // link the two, instead of just failing here.
          throw AccountExistsException(
            email: e.email ?? googleUser.email,
            pendingCredential: credential,
          );
        }
        if (e.code == 'network-request-failed') {
          throw const NetworkUnavailableException();
        }
        rethrow;
      }

      // Create Firestore doc if new user
      final uid = userCred.user!.uid;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (!doc.exists) {
        final displayName = userCred.user!.displayName ?? '';
        final firstName = displayName.trim().isNotEmpty
            ? displayName.trim().split(' ').first
            : '';

        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'uid': uid,
          'email': userCred.user!.email,
          'role': 'user',
          'phoneNumber': userCred.user!.phoneNumber ?? '',
          'savedAreas': [],
          'createdAt': FieldValue.serverTimestamp(),
          'fullName': displayName,
          'firstName': firstName,
          'notifyPowerRestored': true,
          'notifyStatusUpdates': true,
          'notifyVerification': true,
          'notifyAnnouncements': true,
          'notifyMaintenance': true,
        });
      }
      return userCred;
    } on GoogleSignInException catch (e) {
      // v7 throws this when user closes the sheet
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return null; // User cancelled - silent
      }
      rethrow;
    } on AccountExistsException {
      rethrow;
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('cancel') || msg.contains('12501')) {
        return null;
      }
      rethrow;
    }
  }

  // Called after an AccountExistsException: signs in with the existing
  // password account, then links the pending Google credential onto that
  // same account so either sign-in method works from now on. Also
  // backfills fullName from Google if the account didn't already have one
  // saved (e.g. it was created via manual signup without a name field, or
  // an older version of the app).
  Future<UserCredential> linkGoogleWithPassword({
    required String email,
    required String password,
    required AuthCredential pendingCredential,
  }) async {
    try {
      final passwordCred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = passwordCred.user;
      if (user == null) throw 'Sign in failed.';

      final linkedCred = await user.linkWithCredential(pendingCredential);

      final displayName =
          (linkedCred.user?.displayName ?? user.displayName ?? '').trim();
      if (displayName.isNotEmpty) {
        final docRef = _firestore.collection('users').doc(user.uid);
        final doc = await docRef.get();
        final existingFullName = (doc.data()?['fullName'] as String? ?? '')
            .trim();
        if (existingFullName.isEmpty) {
          await docRef.update({
            'fullName': displayName,
            'firstName': displayName.split(' ').first,
          });
        }
      }

      return linkedCred;
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class AccountExistsWithDifferentCredential implements Exception {
  final String email;
  final String message;
  AccountExistsWithDifferentCredential(this.email, [this.message = '']);

  @override
  String toString() => 'AccountExistsWithDifferentCredential: $email $message';
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  AuthCredential? _pendingCredential;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<UserCredential> signInWithEmail(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    try {
      debugPrint(
        'AuthService.signInWithEmail: signed in uid=${cred.user?.uid}',
      );
    } catch (_) {}
    return cred;
  }

  Future<UserCredential> registerWithEmail(
    String email,
    String password,
  ) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    try {
      await cred.user?.sendEmailVerification();
    } catch (_) {}
    // Create a minimal user document in Firestore so security rules and
    // per-user collections can be referenced.
    try {
      final uid = cred.user?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint(
        'AuthService.registerWithEmail: failed to create user doc: $e',
      );
    }

    return cred;
  }

  /// Deletes the current user's Firestore data (user doc and per-user
  /// collections) and then deletes the Firebase Auth account.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user signed in');
    final uid = user.uid;

    final FirebaseFirestore _db = FirebaseFirestore.instance;

    try {
      // Delete user's medicines subcollection documents if present.
      final medsCol = _db.collection('users').doc(uid).collection('medicines');
      final snap = await medsCol.get();
      for (final doc in snap.docs) {
        try {
          // Attempt to remove cloudinary image metadata if present.
          await doc.reference.delete();
        } catch (e) {
          debugPrint(
            'AuthService.deleteAccount: failed deleting doc ${doc.id}: $e',
          );
        }
      }

      // Delete user document
      await _db.collection('users').doc(uid).delete();
    } catch (e) {
      debugPrint('AuthService.deleteAccount: firestore cleanup error: $e');
    }

    // Finally delete the Firebase Auth user
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      // If the user's credentials are too old, client must reauthenticate.
      debugPrint(
        'AuthService.deleteAccount: auth delete failed: ${e.code} ${e.message}',
      );
      rethrow;
    }
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<UserCredential?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null;

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    try {
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        _pendingCredential = credential;
        throw AccountExistsWithDifferentCredential(
          e.email ?? '',
          e.message ?? '',
        );
      }
      rethrow;
    }
  }

  Future<UserCredential?> linkPendingCredentialWithEmailPassword(
    String email,
    String password,
  ) async {
    if (_pendingCredential == null) throw Exception('No pending credential');
    final userCred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = userCred.user;
    if (user == null) throw Exception('User sign-in failed');
    final linked = await user.linkWithCredential(_pendingCredential!);
    _pendingCredential = null;
    return linked;
  }

  String friendlyError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email':
          return 'Invalid email address.';
        case 'user-disabled':
          return 'This user has been disabled.';
        case 'user-not-found':
          return 'No user found with this email.';
        case 'wrong-password':
          return 'Incorrect password.';
        case 'email-already-in-use':
          return 'Email already in use.';
        case 'operation-not-allowed':
          return 'Operation not allowed. Contact support.';
        case 'weak-password':
          return 'Password is too weak.';
        default:
          return e.message ?? 'Authentication error.';
      }
    }
    // Platform / plugin errors
    if (e is PlatformException) {
      return e.message ?? 'A platform error occurred.';
    }
    if (e is MissingPluginException) {
      return e.message ?? 'A plugin error occurred.';
    }

    // Don't show raw Dart `Error`/typecast messages to users; log for debugging.
    if (e is Error) {
      debugPrint('Internal error: $e');
      return 'An unexpected internal error occurred.';
    }

    if (e is Exception) {
      return e.toString();
    }

    return 'An unexpected error occurred.';
  }

  Future<void> signOut() async => _auth.signOut();
}

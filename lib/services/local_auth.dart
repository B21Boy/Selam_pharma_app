import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:hive_flutter/hive_flutter.dart';

class LocalAuth {
  static const _boxName = 'accounts';

  /// Save account for offline login. Password is stored as a salted SHA256 hash.
  static Future<void> saveAccount({
    required String email,
    required String username,
    required String password,
  }) async {
    final box = await Hive.openBox(_boxName);
    final salt = _generateSalt(email);
    final hash = _hashPassword(password, salt);
    await box.put(email.toLowerCase(), {
      'email': email.toLowerCase(),
      'username': username,
      'passwordHash': hash,
      'salt': salt,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Remove all locally stored accounts. Called on explicit sign‑out/delete.
  static Future<void> clearAll() async {
    final box = await Hive.openBox(_boxName);
    await box.clear();
  }

  /// Delete a single account entry by email (case insensitive).
  static Future<void> deleteAccount(String email) async {
    final box = await Hive.openBox(_boxName);
    await box.delete(email.toLowerCase());
  }

  /// Verify credentials against locally stored account. Returns true if match.
  static Future<bool> verifyCredentials(String email, String password) async {
    final box = await Hive.openBox(_boxName);
    final data = box.get(email.toLowerCase());
    if (data == null) return false;
    final salt = data['salt'] as String? ?? '';
    final expected = data['passwordHash'] as String? ?? '';
    final hash = _hashPassword(password, salt);
    return hash == expected;
  }

  static String _generateSalt(String input) {
    // Use a deterministic salt derived from the email to keep it simple.
    // This is not as strong as a random salt, but acceptable for basic offline
    // convenience in this app. If you want stronger security, use a random
    // salt per-account and persist it (we also persist it here).
    final bytes = utf8.encode('salt:${input.toLowerCase()}');
    return base64Url.encode(sha256.convert(bytes).bytes).substring(0, 16);
  }

  static String _hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt:$password');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}

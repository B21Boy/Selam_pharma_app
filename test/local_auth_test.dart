import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shmed/services/local_auth.dart';

void main() {
  setUpAll(() async {
    // Hive needs to be initialized before usage. In a test environment we
    // cannot rely on path_provider, so simply use the current directory.
    final dir = Directory.current;
    Hive.init(dir.path);
  });

  test('LocalAuth.clearAll removes stored accounts', () async {
    const email = 'test@example.com';
    const username = 'tester';
    const password = 'secret';

    // ensure no leftover data from previous runs
    final box = await Hive.openBox('accounts');
    await box.clear();

    // save an account and verify
    await LocalAuth.saveAccount(
      email: email,
      username: username,
      password: password,
    );
    expect(
      box.isNotEmpty,
      isTrue,
      reason: 'Account should be saved before clearing',
    );

    // clear all accounts and verify box empties
    await LocalAuth.clearAll();
    expect(box.isEmpty, isTrue, reason: 'Box should be empty after clearAll');
  });
}

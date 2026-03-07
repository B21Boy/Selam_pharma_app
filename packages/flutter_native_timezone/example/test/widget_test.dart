import 'package:flutter/material.dart';
// ignore: avoid_relative_lib_imports
import '../lib/main.dart' as example;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Verify Platform version', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(example.MyApp());

    // Verify that platform version is retrieved.
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Text &&
            widget.data?.startsWith('Local timezone:') == true,
      ),
      findsOneWidget,
    );
  });
}

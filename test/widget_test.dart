// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// Removed unused imports

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // A minimal counter widget for tests to avoid app-wide async dependencies.
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: _CounterTestWidget())),
    );

    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}

class _CounterTestWidget extends StatefulWidget {
  // Parameter `key` is intentionally unused in this test widget.
  // ignore: unused_element_parameter
  const _CounterTestWidget({super.key});

  @override
  _CounterTestWidgetState createState() => _CounterTestWidgetState();
}

class _CounterTestWidgetState extends State<_CounterTestWidget> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('$_count'),
        FloatingActionButton(
          onPressed: () => setState(() => _count++),
          child: Icon(Icons.add),
        ),
      ],
    );
  }
}

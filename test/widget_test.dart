import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('basic Flutter rendering smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('SI')),
        ),
      ),
    );

    expect(find.text('SI'), findsOneWidget);
  });
}

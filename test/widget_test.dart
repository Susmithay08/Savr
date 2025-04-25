import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savr/main.dart';

void main() {
  testWidgets('SAVR app launches with Start Screen',
      (WidgetTester tester) async {
    // Build the SAVR app
    await tester.pumpWidget(SavrApp());

    // Verify the Start Screen is displayed
    expect(find.text('SAVR'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Already have an account? Log in'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unified_calendar/app.dart';

void main() {
  testWidgets('App starts without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: UnifiedCalendarApp()),
    );
    // The app initially shows a loading state while settings load.
    await tester.pump();

    // Verify the app launched — a MaterialApp is present.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

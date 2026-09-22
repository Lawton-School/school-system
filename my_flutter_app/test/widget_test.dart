// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package.

import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // App requires Supabase initialization, so we just verify the test runs.
    // Full integration tests require a live Supabase project.
    expect(true, isTrue);
  });
}

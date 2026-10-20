// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grit/main.dart';

void main() {
  testWidgets('App boots without crashing', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: GritApp(),
      ),
    );

    // Pump a frame to settle async work triggered by build, then run past
    // the splash intro (SplashScreen.introDuration) so its timer completes.
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    // …and let the login screen's entrance animations finish.
    await tester.pump(const Duration(seconds: 1));
  });
}

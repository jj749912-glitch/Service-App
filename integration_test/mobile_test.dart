import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:solarcare/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Native app opens sign-in and supports new account registration',
    (tester) async {
      await app.main();
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.text('Welcome home.'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('View profile'), findsNothing);
      await tester.ensureVisible(find.text('New here? Create an account'));
      await tester.tap(find.text('New here? Create an account'));
      await tester.pumpAndSettle();
      expect(find.text('Create your account'), findsOneWidget);
      expect(find.text('Full name'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

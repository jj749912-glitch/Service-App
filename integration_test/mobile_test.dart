import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:solarcare/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Native app loads real directory, switches launch cities and opens sign-in',
    (tester) async {
      await app.main();
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.text('Ernakulam'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('View profile'), findsNothing);
      await tester.tap(find.text('Ernakulam'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thrissur').last);
      await tester.pumpAndSettle();
      expect(find.text('Thrissur'), findsOneWidget);
      await tester.tap(find.byTooltip('Your account'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solarcare/app.dart';

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'bookings': '[{"professional_name":"stale local record"}]',
    }),
  );
  testWidgets(
    'Starts in Ernakulam with no generated professionals or bookings',
    (tester) async {
      tester.view.physicalSize = const Size(1300, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const SolarCareApp());
      await tester.pumpAndSettle();
      expect(find.text('Ernakulam'), findsOneWidget);
      expect(find.text('0 professionals in Ernakulam'), findsOneWidget);
      expect(find.text('View profile'), findsNothing);
      await tester.tap(find.text('My bookings'));
      await tester.pumpAndSettle();
      expect(find.text('Your next service starts here'), findsOneWidget);
      expect(find.text('stale local record'), findsNothing);
    },
  );
  testWidgets('Missing backend prompts setup and never simulates sign-in', (
    tester,
  ) async {
    await tester.pumpWidget(const SolarCareApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Your account'));
    await tester.pumpAndSettle();
    expect(
      find.text('Connect Supabase to create an account and book services.'),
      findsOneWidget,
    );
    expect(find.text('Welcome back'), findsNothing);
  });
  testWidgets('Mobile empty directory has no layout overflow', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const SolarCareApp());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}

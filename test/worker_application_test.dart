import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solarcare/provider_data.dart';
import 'package:solarcare/provider_portal.dart';
import 'package:solarcare/mobile/design.dart';
import 'package:solarcare/mobile/login.dart';
import 'auth_gate_test.dart' show TestAuth;

class ApplicationApi implements ProviderApi {
  Map<String, dynamic>? submitted;
  @override
  String get name => 'Real flow test';
  @override
  Future<ProviderSnapshot> load() async => const ProviderSnapshot();
  @override
  Future<void> apply(Map<String, dynamic> fields) async {
    submitted = Map.of(fields);
  }

  @override
  Future<void> change(String id, String status) async {}
  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets(
    'Application requires phone, qualification and every selected service detail',
    (t) async {
      final api = ApplicationApi();
      await t.pumpWidget(
        MaterialApp(
          theme: solarServeTheme(),
          home: ProviderPortal(api: api),
        ),
      );
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Submit application'));
      await t.tap(find.text('Submit application'));
      await t.pumpAndSettle();
      expect(api.submitted, isNull);
      await t.enterText(
        find.widgetWithText(TextFormField, 'Qualification'),
        'Electrical diploma',
      );
      await t.enterText(
        find.widgetWithText(TextFormField, 'Phone number'),
        '9876543210',
      );
      await t.ensureVisible(find.widgetWithText(FilterChip, 'Solar cleaning'));
      await t.tap(find.widgetWithText(FilterChip, 'Solar cleaning'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.widgetWithText(FilterChip, 'Plumbing'));
      await t.tap(find.widgetWithText(FilterChip, 'Plumbing'));
      await t.pumpAndSettle();
      final fields = find.byType(TextFormField);
      // Name, qualification, phone, then the three original fields per service.
      await t.enterText(fields.at(3), '325');
      await t.enterText(fields.at(4), '3');
      await t.enterText(
        fields.at(5),
        'Solar cleaning with original submitted details.',
      );
      await t.enterText(fields.at(6), '450');
      await t.enterText(fields.at(7), '2');
      await t.enterText(
        fields.at(8),
        'Plumbing with original submitted details.',
      );
      await t.ensureVisible(find.text('Submit application'));
      await t.tap(find.text('Submit application'));
      await t.pumpAndSettle();
      expect(api.submitted?['phone'], '+919876543210');
      expect(api.submitted?['qualification'], 'Electrical diploma');
      final services = api.submitted!['services'] as List;
      expect(services.length, 2);
      expect(services.last['service'], 'Plumbing');
      expect(services.last['hourly_rate'], 450);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Email worker registration asks for qualification', (t) async {
    final auth = TestAuth();
    addTearDown(auth.events.close);
    await t.pumpWidget(
      MaterialApp(
        theme: solarServeTheme(),
        home: MobileLoginScreen(api: auth, worker: true),
      ),
    );
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('New to SolarServe? Create an account'));
    await t.tap(find.text('New to SolarServe? Create an account'));
    await t.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Qualification'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
}

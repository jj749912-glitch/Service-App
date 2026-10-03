import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solarcare/mobile/booking_pages.dart';
import 'package:solarcare/mobile/customer_app.dart';
import 'package:solarcare/mobile/customer_data.dart';
import 'package:solarcare/mobile/design.dart';
import 'package:solarcare/provider_data.dart';
import 'package:solarcare/provider_portal.dart';
import 'mobile_customer_test.dart' show TestCustomerApi, testProfessional;

// Shared in-memory responses for UI checks; never connected to Supabase.
class WorkerResponse implements ProviderApi {
  final TestCustomerApi customer;
  bool fail = false;
  WorkerResponse(this.customer);
  @override
  String get name => 'Test Professional';
  @override
  Future<ProviderSnapshot> load() async => ProviderSnapshot(
    professional: {
      'id': testProfessional.id,
      'name': name,
      'service': 'Solar cleaning',
      'hourly_rate': 325,
      'verified': true,
    },
    jobs: customer.snapshot.bookings,
  );
  @override
  Future<void> change(String id, String status) async {
    if (fail) throw StateError('No server row returned');
    customer.snapshot.bookings.singleWhere((b) => b['id'] == id)['status'] =
        status;
  }

  @override
  Future<void> apply(Map<String, dynamic> fields) async {}
  @override
  Future<void> signOut() async {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  void phone(WidgetTester t) {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  Widget shell(Widget child) =>
      MaterialApp(theme: solarServeTheme(), home: child);
  Future<TestCustomerApi> request() async {
    final api = TestCustomerApi(
      const CustomerSnapshot(professionals: [testProfessional]),
    );
    await api.book(
      testProfessional,
      DateTime.now().add(const Duration(days: 2)),
      2,
      'Unit test service address',
      '',
    );
    return api;
  }

  testWidgets(
    'Customer request appears to worker; acceptance and decline return to customer',
    (t) async {
      phone(t);
      for (final decision in ['accepted', 'cancelled']) {
        final api = await request();
        final worker = WorkerResponse(api);
        await t.pumpWidget(shell(ProviderPortal(api: worker)));
        await t.pumpAndSettle();
        expect(find.text('Solar cleaning · requested'), findsOneWidget);
        await t.ensureVisible(
          find.text(decision == 'accepted' ? 'Accept' : 'Decline'),
        );
        await t.tap(find.text(decision == 'accepted' ? 'Accept' : 'Decline'));
        await t.pumpAndSettle();
        expect(find.text('Solar cleaning · $decision'), findsOneWidget);
        expect(find.text('Accept'), findsNothing);
        expect(find.text('Decline'), findsNothing);
        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(
          shell(MobileCustomerApp(api: api, mapsEnabled: false)),
        );
        await t.pumpAndSettle();
        await t.tap(find.text('Jobs').last);
        await t.pumpAndSettle();
        final filter = find.text(
          decision == 'accepted' ? 'Scheduled (1)' : 'Cancelled (1)',
        );
        await t.ensureVisible(filter);
        await t.pumpAndSettle();
        await t.tap(filter);
        await t.pumpAndSettle();
        expect(
          find.text(decision == 'accepted' ? 'Scheduled' : 'Cancelled'),
          findsOneWidget,
        );
        expect(find.text('Test Professional'), findsOneWidget);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      }
    },
  );
  testWidgets('Failed worker update keeps request pending and offers retry', (
    t,
  ) async {
    phone(t);
    final api = await request();
    final worker = WorkerResponse(api)..fail = true;
    await t.pumpWidget(shell(ProviderPortal(api: worker)));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Accept'));
    await t.tap(find.text('Accept'));
    await t.pumpAndSettle();
    expect(api.snapshot.bookings.single['status'], 'requested');
    expect(find.text('Retry'), findsOneWidget);
    worker.fail = false;
    await t.tap(find.text('Retry'));
    await t.pumpAndSettle();
    expect(find.text('Solar cleaning · requested'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('An open booking details screen refreshes a worker decision', (
    t,
  ) async {
    phone(t);
    final api = await request();
    final original = Map<String, dynamic>.of(api.snapshot.bookings.single);
    await t.pumpWidget(
      shell(
        MobileBookingDetails(booking: original, api: api, city: 'Ernakulam'),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Requested'), findsOneWidget);
    api.snapshot.bookings.single['status'] = 'accepted';
    await t.pump(const Duration(seconds: 15));
    await t.pumpAndSettle();
    expect(find.text('Scheduled'), findsOneWidget);
    expect(find.text('Cancel Request'), findsNothing);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:solarcare/app.dart';
import 'package:solarcare/service_offering.dart';
import 'package:solarcare/mobile/booking_journey.dart';
import 'package:solarcare/mobile/customer_data.dart';
import 'package:solarcare/mobile/design.dart';
import 'package:solarcare/mobile/location_map.dart';
import 'package:solarcare/mobile/service_booking.dart';
import 'mobile_customer_test.dart' show TestCustomerApi;

// Isolated widget responses; these tests never connect to the real database.
const multiWorker = Professional(
  'multi',
  'Multi Test Worker',
  'Solar cleaning',
  325,
  0,
  3,
  'Isolated test services.',
  verified: true,
  services: [
    ServiceOffering('Solar cleaning', 325, 3, 'Isolated cleaning details.'),
    ServiceOffering('Plumbing', 450, 2, 'Isolated plumbing details.'),
  ],
);
const partialWorker = Professional(
  'partial',
  'Partial Test Worker',
  'Solar cleaning',
  200,
  0,
  2,
  'Isolated cleaning details.',
  verified: true,
);

class BundleTestApi extends TestCustomerApi implements MultiServiceBookingApi {
  List<Map<String, dynamic>> saved = [];
  DateTime? start;
  int calls = 0;
  BundleTestApi()
    : super(
        const CustomerSnapshot(professionals: [multiWorker, partialWorker]),
      );
  @override
  Future<List<Map<String, dynamic>>> bookServices({
    required String requestId,
    required DateTime start,
    required String address,
    required String notes,
    required LatLng location,
    required List<Map<String, dynamic>> requests,
  }) async {
    calls++;
    this.start = start;
    saved = requests;
    return [
      for (final request in requests)
        {'id': request['professional_id'], 'status': 'requested'},
    ];
  }
}

void main() {
  void size(WidgetTester t) {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  Future<void> services(WidgetTester t, BundleTestApi api) async {
    size(t);
    await t.pumpWidget(
      MaterialApp(
        theme: solarServeTheme(),
        home: BookingJourney(api: api, city: 'Ernakulam', mapsEnabled: false),
      ),
    );
    await t.enterText(
      find.widgetWithText(TextFormField, 'Full service address'),
      'Isolated unit test service address',
    );
    t.widget<LocationMap>(find.byType(LocationMap)).onPick!(
      const LatLng(9.9816, 76.2999),
    );
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Confirm Location'));
    await t.tap(find.text('Confirm Location'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Plumbing'));
    await t.tap(find.text('Plumbing'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Continue to Workers'));
    await t.tap(find.text('Continue to Workers'));
    await t.pumpAndSettle();
  }

  testWidgets(
    'Multiple selection filters one-worker mode and keeps all service rates',
    (t) async {
      final api = BundleTestApi();
      await services(t, api);
      expect(find.text('Multi Test Worker'), findsOneWidget);
      expect(find.text('Partial Test Worker'), findsNothing);
      expect(find.text('Plumbing · ₹450/hr'), findsOneWidget);
      await t.ensureVisible(find.text('Select Worker'));
      await t.tap(find.text('Select Worker'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Continue to Confirm'));
      await t.tap(find.text('Continue to Confirm'));
      await t.pumpAndSettle();
      final page = t.widget<MultiServiceSchedulePage>(
        find.byType(MultiServiceSchedulePage),
      );
      expect(
        page.assignments.keys,
        containsAll(['Solar cleaning', 'Plumbing']),
      );
      expect(page.assignments.values.every((p) => p.id == 'multi'), true);
      expect(api.calls, 0);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Separate-worker mode needs every selected service assigned', (
    t,
  ) async {
    final api = BundleTestApi();
    await services(t, api);
    await t.ensureVisible(find.text('Choose a worker for each service'));
    await t.tap(find.text('Choose a worker for each service'));
    await t.pumpAndSettle();
    expect(find.text('Partial Test Worker'), findsOneWidget);
    await t.ensureVisible(find.text('Select Worker').last);
    await t.tap(find.text('Select Worker').last);
    await t.pumpAndSettle();
    expect(
      t
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Continue to Confirm'),
          )
          .onPressed,
      isNull,
    );
    await t.ensureVisible(find.widgetWithText(ChoiceChip, 'Plumbing'));
    await t.tap(find.widgetWithText(ChoiceChip, 'Plumbing'));
    await t.pumpAndSettle();
    expect(find.text('Partial Test Worker'), findsNothing);
    await t.ensureVisible(find.text('Select Worker'));
    await t.tap(find.text('Select Worker'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Continue to Confirm'));
    await t.tap(find.text('Continue to Confirm'));
    await t.pumpAndSettle();
    final assignments = t
        .widget<MultiServiceSchedulePage>(find.byType(MultiServiceSchedulePage))
        .assignments;
    expect(assignments['Solar cleaning']!.id, 'partial');
    expect(assignments['Plumbing']!.id, 'multi');
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Confirmation sends one grouped request with custom per-service durations',
    (t) async {
      final api = BundleTestApi();
      size(t);
      await t.pumpWidget(
        MaterialApp(
          theme: solarServeTheme(),
          home: MultiServiceSchedulePage(
            api: api,
            assignments: const {
              'Solar cleaning': multiWorker,
              'Plumbing': multiWorker,
            },
            address: 'Isolated unit test service address',
            location: const LatLng(9.98, 76.29),
          ),
        ),
      );
      await t.enterText(
        find.byKey(const ValueKey('duration-Solar cleaning')),
        '75',
      );
      await t.ensureVisible(find.byKey(const ValueKey('duration-Plumbing')));
      await t.enterText(find.byKey(const ValueKey('duration-Plumbing')), '30');
      await t.ensureVisible(
        find.widgetWithText(TextFormField, 'Start time (24-hour HH:mm)'),
      );
      await t.enterText(
        find.widgetWithText(TextFormField, 'Start time (24-hour HH:mm)'),
        '10:35',
      );
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Confirm Services'));
      await t.pumpAndSettle();
      await t.tap(find.text('Confirm Services'));
      await t.pumpAndSettle();
      expect(api.calls, 0);
      expect(find.text('Total labour estimate: ₹632'), findsWidgets);
      await t.tap(find.text('Send Requests'));
      await t.pumpAndSettle();
      expect(api.calls, 1);
      expect(api.saved.length, 1);
      expect((api.saved.single['services'] as List).length, 2);
      expect(api.start!.hour, 10);
      expect(api.start!.minute, 35);
      expect(
        (api.saved.single['services'] as List).first['duration_minutes'],
        75,
      );
      expect(find.text('Requests Saved'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
}

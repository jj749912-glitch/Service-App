import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solarcare/app.dart';
import 'package:solarcare/mobile/booking_pages.dart';
import 'package:solarcare/mobile/components.dart';
import 'package:solarcare/mobile/customer_app.dart';
import 'package:solarcare/mobile/customer_data.dart';
import 'package:solarcare/mobile/design.dart';
import 'package:solarcare/mobile/worker_profile.dart';
import 'package:solarcare/mobile/booking_journey.dart';
import 'package:solarcare/mobile/location_map.dart';
import 'package:solarcare/tracking.dart';
import 'package:latlong2/latlong.dart';
import 'auth_gate_test.dart' show TestAuth;

// Isolated UI responses. Nothing in this file writes to Supabase.
class TestCustomerApi implements MobileCustomerApi, NearbyWorkersApi {
  CustomerSnapshot snapshot;
  int requests = 0;
  DateTime? requestedStart;
  String? requestedAddress;
  TestCustomerApi([this.snapshot = const CustomerSnapshot()]);
  @override
  Future<CustomerSnapshot> load() async => snapshot;
  @override
  Future<List<Map<String, dynamic>>> reviews(String id) async => [];
  @override
  Future<Map<String, dynamic>> book(
    Professional p,
    DateTime start,
    num hours,
    String address,
    String notes, {
    double? latitude,
    double? longitude,
  }) async {
    requests++;
    requestedStart = start;
    requestedAddress = address.trim();
    final record = <String, dynamic>{
      'id': 'unit-test-booking',
      'professional_id': p.id,
      'professional_name': p.name,
      'service': p.service,
      'starts_at': start.toUtc().toIso8601String(),
      'ends_at': start
          .add(Duration(minutes: (hours * 60).round()))
          .toUtc()
          .toIso8601String(),
      'hours': hours,
      'address': address.trim(),
      'notes': notes.trim(),
      'total': (p.rate * hours).ceil(),
      'duration_minutes': (hours * 60).round(),
      'status': 'requested',
    };
    snapshot = CustomerSnapshot(
      userId: snapshot.userId,
      name: snapshot.name,
      email: snapshot.email,
      professionals: snapshot.professionals,
      bookings: [record, ...snapshot.bookings],
    );
    return record;
  }

  @override
  Future<void> cancel(String id) async {}
  @override
  Future<void> rename(String name) async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<List<Map<String, dynamic>>> availableWorkers() async => [
    for (final p in snapshot.professionals)
      {
        'professional_id': p.id,
        'latitude': 9.9816,
        'longitude': 76.2999,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
  ];
}

const testProfessional = Professional(
  'unit-test-professional',
  'Test Professional',
  'Solar cleaning',
  325,
  0,
  3,
  'Unit test biography.',
  verified: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('Poppins');
    for (final style in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      loader.addFont(rootBundle.load('assets/fonts/Poppins-$style.ttf'));
    }
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'bookings': '[{"professional_name":"stale local record"}]',
      'saved': ['stale-profile'],
      'mobile_saved_': ['missing-profile'],
    }),
  );
  void mobileSize(WidgetTester t, [double width = 390]) {
    t.view.physicalSize = Size(width, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  Widget shell(Widget child) =>
      MaterialApp(theme: solarServeTheme(), home: child);
  for (final width in [390.0, 1440.0]) {
    for (final admin in [false, true]) {
      testWidgets(
        'Admin menu visibility at width $width requires permission $admin',
        (t) async {
          mobileSize(t, width);
          final api = TestCustomerApi(CustomerSnapshot(admin: admin));
          await t.pumpWidget(
            shell(MobileCustomerApp(api: api, mapsEnabled: false)),
          );
          await t.pumpAndSettle();
          if (width < 900) {
            await t.tap(find.text('Profile').last);
            await t.pumpAndSettle();
            await t.scrollUntilVisible(
              find.text('Account Overview'),
              250,
              scrollable: find.byType(Scrollable).first,
            );
          }
          expect(
            find.text('Admin Dashboard'),
            admin ? findsOneWidget : findsNothing,
          );
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
  Future<void> screen(WidgetTester t, String filename) async {
    // Optional local visual checks, captured only from empty states.
    if (!const bool.fromEnvironment('CAPTURE_MOBILE_UI')) return;
    final context = t.element(find.byType(Scaffold).first);
    await t.runAsync(
      () => Future.wait([
        for (final name in [
          'solar-house',
          'solar-cleaning',
          'solar-maintenance',
          'electrical',
          'plumbing',
          'cleaning',
          'repair',
        ])
          precacheImage(AssetImage('assets/mobile/$name.png'), context),
      ]),
    );
    await t.pump();
    final boundary = t.firstRenderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary).first,
    );
    await t.runAsync(() async {
      final img = await boundary.toImage(pixelRatio: 2);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      await Directory('dist/mobile-ui').create(recursive: true);
      await File(
        'dist/mobile-ui/$filename.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      img.dispose();
    });
  }

  testWidgets('Empty mobile directory and jobs never use sample records', (
    t,
  ) async {
    mobileSize(t);
    await t.pumpWidget(
      shell(MobileCustomerApp(api: TestCustomerApi(), mapsEnabled: false)),
    );
    await t.pumpAndSettle();
    expect(find.text('Ernakulam, Kerala'), findsOneWidget);
    expect(find.byType(ProfessionalTile), findsNothing);
    expect(find.text('Arjun K'), findsNothing);
    expect(find.text('No professionals in Ernakulam yet'), findsOneWidget);
    await screen(t, 'home');
    await t.tap(find.text('Explore').last);
    await t.pumpAndSettle();
    expect(find.byType(ProfessionalTile), findsNothing);
    expect(t.takeException(), isNull);
    await screen(t, 'explore');
    await t.tap(find.text('Jobs').last);
    await t.pumpAndSettle();
    expect(find.text('Scheduled (0)'), findsOneWidget);
    expect(find.text('Completed (0)'), findsOneWidget);
    expect(find.text('stale local record'), findsNothing);
    await screen(t, 'jobs');
    await t.tap(find.text('Messages').last);
    await t.pumpAndSettle();
    expect(find.text('Arjun K'), findsNothing);
    expect(
      find.textContaining('Conversations become available'),
      findsOneWidget,
    );
    await screen(t, 'messages');
    await t.tap(find.text('Profile').last);
    await t.pumpAndSettle();
    expect(find.text('Gold Member'), findsNothing);
    expect(find.text('No Plan'), findsOneWidget);
    expect(t.takeException(), isNull);
    await screen(t, 'profile');
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('Only approved professionals from the selected city appear', (
    t,
  ) async {
    mobileSize(t, 360);
    final api = TestCustomerApi(
      const CustomerSnapshot(
        professionals: [
          testProfessional,
          Professional(
            'pending-test',
            'Pending Test',
            'Electrical',
            1,
            0,
            0,
            '',
          ),
          Professional(
            'thrissur-test',
            'Thrissur Test',
            'Plumbing',
            420,
            4.5,
            7,
            '',
            city: 'Thrissur',
            verified: true,
            reviewCount: 2,
          ),
        ],
      ),
    );
    await t.pumpWidget(shell(MobileCustomerApp(api: api, mapsEnabled: false)));
    await t.pumpAndSettle();
    expect(find.byType(ProfessionalTile), findsOneWidget);
    expect(find.text('Test Professional'), findsOneWidget);
    expect(find.text('₹325/hr'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    expect(find.text('Pending Test'), findsNothing);
    expect(find.text('Thrissur Test'), findsNothing);
    expect(t.takeException(), isNull);
    await t.tap(find.byType(DropdownButton<String>));
    await t.pumpAndSettle();
    await t.tap(find.text('Thrissur, Kerala').last);
    await t.pumpAndSettle();
    expect(find.text('Test Professional'), findsNothing);
    expect(find.text('Thrissur Test'), findsOneWidget);
    expect(find.text('4.5'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Profile shows recorded rate and experience without invented reviews',
    (t) async {
      mobileSize(t, 360);
      await t.pumpWidget(
        shell(
          MobileWorkerProfile(
            professional: testProfessional,
            api: TestCustomerApi(),
            city: 'Ernakulam',
            onTab: (_) {},
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Test Professional'), findsOneWidget);
      expect(find.text('New'), findsOneWidget);
      expect(find.textContaining('3 Years'), findsOneWidget);
      expect(find.text('ID Verified'), findsNothing);
      expect(find.text('Insured'), findsNothing);
      expect(find.text('350+'), findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Booking validates address and writes only after confirmation', (
    t,
  ) async {
    mobileSize(t, 360);
    final api = TestCustomerApi();
    await t.pumpWidget(
      shell(
        MobileSchedulePage(
          professional: testProfessional,
          api: api,
          city: 'Ernakulam',
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.ensureVisible(find.text('Confirm Schedule'));
    await t.tap(find.text('Confirm Schedule'));
    await t.pumpAndSettle();
    expect(api.requests, 0);
    expect(
      find.text('Enter a full address (at least 10 characters).'),
      findsOneWidget,
    );
    await t.enterText(
      find.widgetWithText(TextFormField, 'Service address'),
      'Unit test address only',
    );
    await t.ensureVisible(find.text('Confirm Schedule'));
    await t.tap(find.text('Confirm Schedule'));
    await t.pumpAndSettle();
    expect(api.requests, 0);
    expect(find.text('Confirm Your Schedule'), findsOneWidget);
    await t.tap(find.text('Send Request'));
    await t.pumpAndSettle();
    expect(api.requests, 1);
    expect(api.requestedStart!.isAfter(DateTime.now()), isTrue);
    expect(api.requestedAddress, 'Unit test address only');
    expect(find.textContaining('Labour estimate: ₹650'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Explore books the worker for the filtered service and opens My Jobs',
    (t) async {
      mobileSize(t, 360);
      final api = TestCustomerApi(
        const CustomerSnapshot(
          professionals: [
            testProfessional,
            Professional(
              'plumber-test',
              'Plumbing Test',
              'Plumbing',
              420,
              0,
              4,
              '',
              verified: true,
            ),
          ],
        ),
      );
      await t.pumpWidget(
        shell(MobileCustomerApp(api: api, mapsEnabled: false)),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Explore').last);
      await t.pumpAndSettle();
      expect(find.byType(FilterChip), findsNWidgets(7));
      for (final service in mobileServices) {
        await t.ensureVisible(
          find.widgetWithText(FilterChip, displayService(service)),
        );
        await t.pumpAndSettle();
        expect(
          find
              .widgetWithText(FilterChip, displayService(service))
              .hitTestable(),
          findsOneWidget,
        );
      }
      await t.ensureVisible(
        find.widgetWithText(FilterChip, 'Solar Maintenance'),
      );
      await t.tap(find.widgetWithText(FilterChip, 'Solar Maintenance'));
      await t.pumpAndSettle();
      expect(find.byType(ProfessionalTile), findsNothing);
      await t.ensureVisible(find.widgetWithText(FilterChip, 'Solar Cleaning'));
      await t.tap(find.widgetWithText(FilterChip, 'Solar Cleaning'));
      await t.pumpAndSettle();
      expect(find.byType(ProfessionalTile), findsOneWidget);
      expect(find.text('Plumbing Test'), findsNothing);
      expect(find.text('View Profile & Reviews'), findsOneWidget);
      await t.ensureVisible(find.text('Book'));
      await t.tap(find.text('Book'));
      await t.pumpAndSettle();
      expect(find.byType(BookingJourney), findsOneWidget);
      expect(find.text('Select Your Location'), findsOneWidget);
      await t.enterText(
        find.widgetWithText(TextFormField, 'Full service address'),
        'Unit test service address',
      );
      t.widget<LocationMap>(find.byType(LocationMap)).onPick!(
        const LatLng(9.9816, 76.2999),
      );
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Confirm Location'));
      await t.tap(find.text('Confirm Location'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Continue to Workers'));
      await t.tap(find.text('Continue to Workers'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Select Worker'));
      await t.tap(find.text('Select Worker'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Continue to Confirm'));
      await t.tap(find.text('Continue to Confirm'));
      await t.pumpAndSettle();
      final schedule = t.widget<MobileSchedulePage>(
        find.byType(MobileSchedulePage),
      );
      expect(schedule.professional.id, testProfessional.id);
      expect(schedule.professional.service, 'Solar cleaning');
      expect(api.requests, 0);
      await t.enterText(
        find.widgetWithText(TextFormField, 'Service address'),
        'Unit test service address',
      );
      await t.ensureVisible(find.text('Confirm Schedule'));
      await t.tap(find.text('Confirm Schedule'));
      await t.pumpAndSettle();
      await t.tap(find.text('Send Request'));
      await t.pumpAndSettle();
      await t.tap(find.text('View My Jobs'));
      await t.pumpAndSettle();
      expect(api.requests, 1);
      expect(find.text('My Jobs'), findsOneWidget);
      expect(find.text('Scheduled (1)'), findsOneWidget);
      expect(find.text('Test Professional'), findsOneWidget);
      expect(find.text('₹650'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Mobile login remains gated and signup awaits confirmation', (
    t,
  ) async {
    mobileSize(t, 360);
    final auth = TestAuth()..fail = true;
    addTearDown(auth.events.close);
    await t.pumpWidget(
      SolarCareApp(
        mobile: true,
        auth: auth,
        homeBuilder: (_) => const Scaffold(body: Text('Protected content')),
      ),
    );
    await t.pumpAndSettle();
    await screen(t, 'login');
    await t.enterText(find.byType(TextFormField).at(0), 'test@example.invalid');
    await t.enterText(find.byType(TextFormField).at(1), 'unit-test-password');
    await t.ensureVisible(find.text('Login'));
    await t.tap(find.text('Login'));
    await t.pumpAndSettle();
    expect(find.text('Invalid login credentials'), findsOneWidget);
    expect(find.text('Protected content'), findsNothing);
    await t.ensureVisible(find.text('New to SolarServe? Create an account'));
    await t.tap(find.text('New to SolarServe? Create an account'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField).at(0), 'Unit Test');
    await t.enterText(find.byType(TextFormField).at(1), 'test@example.invalid');
    await t.enterText(find.byType(TextFormField).at(2), 'unit-test-password');
    await t.enterText(find.byType(TextFormField).at(3), 'unit-test-password');
    await t.ensureVisible(find.text('Create Account'));
    await t.tap(find.text('Create Account'));
    await t.pumpAndSettle();
    expect(auth.signUps, 1);
    expect(find.text('Protected content'), findsNothing);
    expect(find.textContaining('Check your email to confirm'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform selects SolarServe login before the app opens',
      (t) async {
        final auth = TestAuth();
        addTearDown(auth.events.close);
        await t.pumpWidget(
          SolarCareApp(
            auth: auth,
            homeBuilder: (_) => const Text('Protected content'),
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('Welcome Back.'), findsOneWidget);
        expect(find.text('Protected content'), findsNothing);
      },
      variant: TargetPlatformVariant({platform}),
    );
  }

  testWidgets('Small phone with larger text supports every customer tab', (
    t,
  ) async {
    mobileSize(t, 360);
    await t.pumpWidget(
      MaterialApp(
        theme: solarServeTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.4)),
          child: child!,
        ),
        home: MobileCustomerApp(api: TestCustomerApi(), mapsEnabled: false),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    for (final tab in ['Explore', 'Jobs', 'Messages', 'Profile']) {
      await t.tap(find.text(tab).last);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: 'Layout of $tab');
    }
    await t.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Wide web layout keeps booking routes and dialogs in the mobile frame',
    (t) async {
      t.view.physicalSize = const Size(1280, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final auth = TestAuth()..userId = 'frame-test';
      addTearDown(auth.events.close);
      await t.pumpWidget(
        SolarCareApp(
          mobile: true,
          auth: auth,
          homeBuilder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MobileSchedulePage(
                    professional: testProfessional,
                    api: TestCustomerApi(),
                    city: 'Ernakulam',
                  ),
                ),
              ),
              child: const Text('Open booking'),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Open booking'));
      await t.pumpAndSettle();
      expect(t.getSize(find.byType(Scaffold).last).width, 480);
      expect(
        MediaQuery.sizeOf(t.element(find.byType(MobileSchedulePage))).width,
        480,
      );
      await t.enterText(
        find.widgetWithText(TextFormField, 'Service address'),
        'Unit test service address',
      );
      await t.ensureVisible(find.text('Confirm Schedule'));
      await t.tap(find.text('Confirm Schedule'));
      await t.pumpAndSettle();
      expect(find.text('Confirm Your Schedule'), findsOneWidget);
      expect(t.getSize(find.byType(AlertDialog)).width, lessThanOrEqualTo(480));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
}

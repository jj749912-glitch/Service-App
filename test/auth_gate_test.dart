import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solarcare/app.dart';
import 'package:solarcare/auth_gate.dart';
import 'package:solarcare/worker_app.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// In-memory auth responses only. These tests never create backend records.
class TestAuth implements AppAuthApi {
  final events = StreamController<String?>.broadcast();
  @override
  String? userId;
  bool fail = false;
  int signIns = 0, signUps = 0;
  List<String>? registration;
  String? submittedQualification;
  @override
  Stream<String?> get changes => events.stream;
  void session(String? id) {
    userId = id;
    events.add(id);
  }

  @override
  Future<void> signIn(String email, String password) async {
    signIns++;
    if (fail) throw const AuthException('Invalid login credentials');
    session('test-session');
  }

  @override
  Future<bool> signUp(
    String name,
    String email,
    String password, {
    String? qualification,
  }) async {
    signUps++;
    registration = [name, email, password];
    submittedQualification = qualification;
    return true;
  }

  @override
  Future<void> resendConfirmation(String email) async {}
}

void main() {
  late TestAuth api;
  setUp(() => api = TestAuth());
  tearDown(() => api.events.close());
  Widget customer() => SolarCareApp(
    auth: api,
    mobile: false,
    homeBuilder: (_) => const Scaffold(body: Text('Customer workspace')),
  );
  Future<void> credentials(WidgetTester t) async {
    await t.enterText(
      find.byType(TextFormField).at(0),
      'customer@example.invalid',
    );
    await t.enterText(find.byType(TextFormField).at(1), 'test-password');
    await t.ensureVisible(find.widgetWithText(FilledButton, 'Sign in'));
    await t.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await t.pumpAndSettle();
  }

  testWidgets('Customer app requires sign-in before protected content', (
    t,
  ) async {
    await t.pumpWidget(customer());
    expect(find.text('Welcome home.'), findsOneWidget);
    expect(find.text('Customer workspace'), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    await credentials(t);
    expect(api.signIns, 1);
    expect(find.text('Customer workspace'), findsOneWidget);
    expect(find.text('Welcome home.'), findsNothing);
  });
  testWidgets('Failed login cannot open the customer app', (t) async {
    api.fail = true;
    await t.pumpWidget(customer());
    await credentials(t);
    expect(find.text('Invalid login credentials'), findsOneWidget);
    expect(find.text('Customer workspace'), findsNothing);
  });
  testWidgets('New users register with name and await email confirmation', (
    t,
  ) async {
    await t.pumpWidget(customer());
    await t.ensureVisible(find.text('New here? Create an account'));
    await t.tap(find.text('New here? Create an account'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField).at(0), 'New customer');
    await t.enterText(find.byType(TextFormField).at(1), 'new@example.invalid');
    await t.enterText(find.byType(TextFormField).at(2), 'test-password');
    await t.enterText(find.byType(TextFormField).at(3), 'different-password');
    await t.ensureVisible(find.widgetWithText(FilledButton, 'Create account'));
    await t.tap(find.widgetWithText(FilledButton, 'Create account'));
    await t.pumpAndSettle();
    expect(api.signUps, 0);
    expect(find.text('Passwords must match.'), findsOneWidget);
    await t.enterText(find.byType(TextFormField).at(3), 'test-password');
    await t.ensureVisible(find.widgetWithText(FilledButton, 'Create account'));
    await t.tap(find.widgetWithText(FilledButton, 'Create account'));
    await t.pumpAndSettle();
    expect(api.registration, [
      'New customer',
      'new@example.invalid',
      'test-password',
    ]);
    expect(
      find.text('Check your email to confirm your account, then sign in here.'),
      findsOneWidget,
    );
    expect(find.text('Customer workspace'), findsNothing);
  });
  testWidgets('Sign-out closes protected routes and returns to login', (
    t,
  ) async {
    api.userId = 'existing-session';
    await t.pumpWidget(customer());
    await t.pumpAndSettle();
    final navigator = t.state<NavigatorState>(find.byType(Navigator).first);
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Private details')),
        ),
      ),
    );
    await t.pumpAndSettle();
    api.session(null);
    await t.pumpAndSettle();
    expect(find.text('Private details'), findsNothing);
    expect(find.text('Customer workspace'), findsNothing);
    expect(find.text('Welcome home.'), findsOneWidget);
  });
  testWidgets('Direct admin navigation is gated for signed-out visitors', (
    t,
  ) async {
    await t.pumpWidget(customer());
    unawaited(
      t.state<NavigatorState>(find.byType(Navigator).first).pushNamed('/admin'),
    );
    await t.pumpAndSettle();
    expect(find.text('Welcome home.'), findsOneWidget);
    expect(find.text('Admin dashboard'), findsNothing);
  });
  testWidgets('Worker app has its own login and protected workspace', (
    t,
  ) async {
    await t.pumpWidget(
      SolarCareWorkerApp(
        auth: api,
        workspaceBuilder: (_) => const Scaffold(body: Text('Worker workspace')),
      ),
    );
    expect(find.text('Welcome Back, Pro.'), findsOneWidget);
    expect(find.text('Worker workspace'), findsNothing);
    await t.enterText(
      find.byType(TextFormField).at(0),
      'worker@example.invalid',
    );
    await t.enterText(find.byType(TextFormField).at(1), 'test-password');
    await t.ensureVisible(find.text('Login'));
    await t.tap(find.text('Login'));
    await t.pumpAndSettle();
    expect(find.text('Worker workspace'), findsOneWidget);
    api.session(null);
    await t.pumpAndSettle();
    expect(find.text('Welcome Back, Pro.'), findsOneWidget);
  });
  testWidgets('Mobile signup stays scrollable above the keyboard', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    t.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetViewInsets);
    await t.pumpWidget(customer());
    await t.ensureVisible(find.text('New here? Create an account'));
    await t.tap(find.text('New here? Create an account'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.widgetWithText(FilledButton, 'Create account'));
    expect(t.takeException(), isNull);
  });
}

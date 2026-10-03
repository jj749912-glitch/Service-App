import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solarcare/admin_portal.dart';
import 'package:solarcare/worker_approval_notice.dart';

class TestAdminApi implements AdminApi {
  bool allowed;
  int reads = 0;
  TestAdminApi({this.allowed = false});
  @override
  Future<bool> hasAccess() async => allowed;
  @override
  Future<Map<String, dynamic>> summary() async {
    reads++;
    return {'pending': 0, 'approved': 0, 'active_bookings': 0, 'users': 1};
  }

  @override
  Future<Map<String, dynamic>> list(
    String section,
    String status,
    int offset,
  ) async {
    reads++;
    return {'total': 0, 'items': <Map<String, dynamic>>[]};
  }

  @override
  Future<void> review(
    Map<String, dynamic> worker,
    String status,
    String note,
    bool checked,
  ) async {}
  @override
  Future<void> updateProfile(
    String id,
    Map<String, dynamic> profile,
    String note,
  ) async {}
  @override
  Future<void> cancelBooking(String id, String note) async {}
}

void main() {
  testWidgets('Unauthorized accounts never load admin records', (tester) async {
    final api = TestAdminApi();
    await tester.pumpWidget(MaterialApp(home: AdminPortal(api: api)));
    await tester.pumpAndSettle();
    expect(find.text('Administrator access required'), findsOneWidget);
    expect(api.reads, 0);
    expect(find.text('Workers'), findsNothing);
  });
  testWidgets('Mobile empty dashboard and revoked access remain safe', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = TestAdminApi(allowed: true);
    await tester.pumpWidget(MaterialApp(home: AdminPortal(api: api)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Awaiting approval'), findsOneWidget);
    api.allowed = false;
    await tester.tap(find.byTooltip('Refresh dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('Administrator access required'), findsOneWidget);
    expect(find.text('Awaiting approval'), findsNothing);
  });
  testWidgets('Approval requires every verification check and a reason', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    int approvals = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminActionDialog(
            title: 'Review worker',
            description: 'Verify this application.',
            confirmLabel: 'Approve worker',
            requireChecks: true,
            onConfirm: (note, checked) async {
              expect(checked, isTrue);
              expect(note, 'Identity and qualifications verified');
              approvals++;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Approve worker'),
          )
          .onPressed,
      isNull,
    );
    for (final checkbox in find.byType(CheckboxListTile).evaluate().toList()) {
      await tester.tap(find.byWidget(checkbox.widget));
      await tester.pump();
    }
    await tester.tap(find.text('Approve worker'));
    await tester.pump();
    expect(approvals, 0);
    expect(
      find.text('Enter a reason of at least 5 characters.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byType(TextField),
      'Identity and qualifications verified',
    );
    await tester.tap(find.text('Approve worker'));
    await tester.pumpAndSettle();
    expect(approvals, 1);
  });
  testWidgets('Workers see suspension and admin review, without job actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WorkerApprovalNotice(
            status: 'suspended',
            note: 'Qualification review required',
          ),
        ),
      ),
    );
    expect(find.text('Worker access suspended'), findsOneWidget);
    expect(find.text('Qualification review required'), findsOneWidget);
    expect(find.text('Accept'), findsNothing);
  });
}

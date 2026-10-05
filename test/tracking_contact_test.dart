import 'package:flutter_test/flutter_test.dart';
import 'package:solarcare/tracking.dart';
import 'package:solarcare/mobile/booking_contact.dart';
import 'package:solarcare/app.dart';
import 'package:solarcare/service_offering.dart';

void main() {
  final start = DateTime.utc(2026, 10, 5, 4, 30);
  Map<String, dynamic> booking(String status) => {
    'status': status,
    'starts_at': start.toIso8601String(),
    'ends_at': start.add(const Duration(minutes: 75)).toIso8601String(),
  };
  test(
    'Precise tracking starts at 20 minutes and ends at completion or visit end',
    () {
      final b = booking('accepted');
      expect(
        trackingWindowOpen(
          b,
          start.subtract(const Duration(minutes: 20, seconds: 1)),
        ),
        false,
      );
      expect(
        trackingWindowOpen(b, start.subtract(const Duration(minutes: 20))),
        true,
      );
      expect(
        trackingWindowOpen(
          b,
          start.add(const Duration(minutes: 74, seconds: 59)),
        ),
        true,
      );
      expect(
        trackingWindowOpen(b, start.add(const Duration(minutes: 75))),
        false,
      );
      for (final status in ['requested', 'cancelled', 'completed']) {
        expect(trackingWindowOpen(booking(status), start), false);
      }
    },
  );
  test('Phone access follows the confirmed India appointment day', () {
    final b = booking('accepted');
    expect(
      appointmentDayContactAllowed(b, DateTime.utc(2026, 10, 4, 18, 29, 59)),
      false,
    );
    expect(
      appointmentDayContactAllowed(b, DateTime.utc(2026, 10, 4, 18, 30)),
      true,
    );
    expect(
      appointmentDayContactAllowed(b, DateTime.utc(2026, 10, 5, 18, 29, 59)),
      true,
    );
    expect(
      appointmentDayContactAllowed(b, DateTime.utc(2026, 10, 5, 18, 30)),
      false,
    );
    expect(appointmentDayContactAllowed(booking('requested'), start), false);
    expect(appointmentDayContactAllowed(booking('cancelled'), start), false);
    expect(appointmentDayContactAllowed(booking('completed'), start), true);
  });
  test(
    'A selected secondary service uses its own original rate and details',
    () {
      const p = Professional(
        'id',
        'Worker',
        'Solar cleaning',
        325,
        0,
        3,
        'Primary service details',
        verified: true,
        services: [
          ServiceOffering('Solar cleaning', 325, 3, 'Primary service details'),
          ServiceOffering('Plumbing', 450, 2, 'Secondary service details'),
        ],
      );
      final plumbing = p.forService('Plumbing');
      expect(plumbing.id, p.id);
      expect(plumbing.rate, 450);
      expect(plumbing.years, 2);
      expect(plumbing.bio, 'Secondary service details');
      expect(plumbing.offers('Electrical'), false);
    },
  );
}

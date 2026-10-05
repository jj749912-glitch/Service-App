import 'package:supabase_flutter/supabase_flutter.dart';
import '../app.dart' show Professional;
import '../admin_portal.dart';
import '../tracking.dart';

class CustomerSnapshot {
  final String userId, name, email, phone;
  final List<Professional> professionals;
  final List<Map<String, dynamic>> bookings;
  final List<Map<String, dynamic>> notifications;
  final bool admin;
  const CustomerSnapshot({
    this.userId = '',
    this.name = '',
    this.email = '',
    this.phone = '',
    this.professionals = const [],
    this.bookings = const [],
    this.notifications = const [],
    this.admin = false,
  });
}

abstract class MobileCustomerApi {
  Future<CustomerSnapshot> load();
  Future<List<Map<String, dynamic>>> reviews(String professionalId);
  Future<Map<String, dynamic>> book(
    Professional professional,
    DateTime start,
    num hours,
    String address,
    String notes, {
    double? latitude,
    double? longitude,
  });
  Future<void> cancel(String bookingId);
  Future<void> rename(String name);
  Future<void> signOut();
}

class SupabaseMobileCustomerApi
    implements
        MobileCustomerApi,
        BookingUpdatesApi,
        NearbyWorkersApi,
        WorkerContactApi {
  final SupabaseClient client;
  SupabaseMobileCustomerApi(this.client);
  @override
  Future<CustomerSnapshot> load() async {
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Sign in to continue.');
    final results = await Future.wait<dynamic>([
      client
          .from('professional_directory')
          .select()
          .eq('verified', true)
          .order('name'),
      client
          .from('bookings')
          .select()
          .eq('customer_id', user.id)
          .order('starts_at', ascending: false),
      SupabaseAdminApi(client).hasAccess(),
      client
          .from('booking_notifications')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(100),
    ]);
    return CustomerSnapshot(
      userId: user.id,
      name: user.userMetadata?['full_name'] as String? ?? '',
      email: user.email ?? '',
      phone: user.phone ?? '',
      professionals: (results[0] as List)
          .map((r) => Professional.fromJson(Map<String, dynamic>.from(r)))
          .toList(),
      bookings: (results[1] as List)
          .map((r) => Map<String, dynamic>.from(r))
          .toList(),
      admin: results[2] as bool,
      notifications: (results[3] as List)
          .map((r) => Map<String, dynamic>.from(r))
          .toList(),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> reviews(String professionalId) async =>
      await client
          .from('reviews')
          .select('author_name,rating,body,created_at')
          .eq('professional_id', professionalId)
          .order('created_at', ascending: false);
  @override
  Future<Map<String, dynamic>> book(
    Professional professional,
    DateTime start,
    num hours,
    String address,
    String notes, {
    double? latitude,
    double? longitude,
  }) async {
    if (client.auth.currentUser == null) {
      throw const AuthException('Sign in to continue.');
    }
    return await client
        .from('bookings')
        .insert({
          'customer_id': client.auth.currentUser!.id,
          'professional_id': professional.id,
          'professional_name': professional.name,
          'service': professional.service,
          'starts_at': start.toUtc().toIso8601String(),
          'hours': hours,
          'duration_minutes': (hours * 60).round(),
          'address': address.trim(),
          'notes': notes.trim(),
          'customer_latitude': latitude,
          'customer_longitude': longitude,
          'total': (professional.rate * hours).ceil(),
          'status': 'requested',
        })
        .select()
        .single();
  }

  @override
  Future<void> cancel(String bookingId) =>
      client.rpc('cancel_booking', params: {'booking_id': bookingId});
  @override
  Future<void> rename(String name) async {
    await client.auth.updateUser(
      UserAttributes(data: {'full_name': name.trim()}),
    );
  }

  @override
  Future<void> signOut() => client.auth.signOut(scope: SignOutScope.local);

  @override
  Stream<void> get bookingChanges => client
      .from('bookings')
      .stream(primaryKey: ['id'])
      .eq('customer_id', client.auth.currentUser!.id)
      .map((_) {});
  @override
  Future<void> readNotifications(List<String> ids) async {
    if (ids.isEmpty) return;
    await client
        .from('booking_notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .inFilter('id', ids)
        .eq('user_id', client.auth.currentUser!.id);
  }

  @override
  Future<Map<String, dynamic>?> workerLocation(String bookingId) async =>
      await client
          .from('worker_locations')
          .select()
          .eq('booking_id', bookingId)
          .maybeSingle();
  @override
  Future<List<Map<String, dynamic>>> availableWorkers() async => await client
      .from('worker_availability')
      .select()
      .gte(
        'updated_at',
        DateTime.now()
            .toUtc()
            .subtract(const Duration(minutes: 2))
            .toIso8601String(),
      );

  @override
  Future<String?> workerPhone(String professionalId) async {
    final row = await client
        .from('worker_contacts')
        .select('phone')
        .eq('professional_id', professionalId)
        .maybeSingle();
    return row?['phone'] as String?;
  }
}

String displayService(String value) => switch (value) {
  'Solar cleaning' => 'Solar Cleaning',
  'Solar inspection' => 'Solar Maintenance',
  'Solar repair' => 'Solar Repair',
  'Electrical' => 'Electrician',
  'Home cleaning' => 'Cleaning',
  _ => value,
};

String bookingStatus(Map<String, dynamic> booking) =>
    switch (booking['status']) {
      'requested' => 'Requested',
      'accepted' => 'Confirmed',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      _ => 'Awaiting update',
    };

String formatDate(DateTime date) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
}

String formatTime(DateTime date) =>
    '${date.hour % 12 == 0 ? 12 : date.hour % 12}:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}';

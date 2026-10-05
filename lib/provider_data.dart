import 'package:supabase_flutter/supabase_flutter.dart';
import 'tracking.dart';

class ProviderSnapshot {
  final Map<String, dynamic>? professional, review;
  final List<Map<String, dynamic>> jobs;
  final String qualification;
  final String phone;
  const ProviderSnapshot({
    this.professional,
    this.review,
    this.jobs = const [],
    this.qualification = '',
    this.phone = '',
  });
}

abstract class ProviderApi {
  String get name;
  Future<ProviderSnapshot> load();
  Future<void> apply(Map<String, dynamic> fields);
  Future<void> change(String bookingId, String status);
  Future<void> signOut();
}

class SupabaseProviderApi implements ProviderApi, WorkerUpdatesApi {
  final SupabaseClient client;
  SupabaseProviderApi(this.client);
  @override
  String get name =>
      client.auth.currentUser?.userMetadata?['full_name'] as String? ?? '';
  @override
  Future<ProviderSnapshot> load() async {
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Sign in to continue.');
    final p = await client
        .from('professional_directory')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();
    final decision = p == null ? null : await client.rpc('my_worker_review');
    final contact = p == null
        ? null
        : await client
              .from('worker_contacts')
              .select('phone')
              .eq('professional_id', p['id'])
              .maybeSingle();
    final jobs = p?['verified'] != true
        ? <Map<String, dynamic>>[]
        : await client
              .from('bookings')
              .select()
              .eq('professional_id', p!['id'])
              .order('starts_at');
    return ProviderSnapshot(
      professional: p,
      phone: contact?['phone'] as String? ?? '',
      qualification: user.userMetadata?['qualification'] as String? ?? '',
      review: decision == null ? null : Map<String, dynamic>.from(decision),
      jobs: jobs,
    );
  }

  @override
  Future<void> apply(Map<String, dynamic> fields) async {
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Sign in to continue.');
    await client.rpc(
      'submit_worker_application',
      params: {'application': fields},
    );
  }

  @override
  Future<void> change(String bookingId, String status) async {
    // RLS can match no rows after suspension or a concurrent decision.
    // Require the server's returned row before reporting success.
    final row = await client
        .from('bookings')
        .update({'status': status})
        .eq('id', bookingId)
        .select('id,status')
        .single();
    if (row['status'] != status) throw StateError('Booking was not updated.');
  }

  Future<Map<String, dynamic>> milestone(
    String bookingId,
    String next, {
    String? notes,
  }) async => await client
      .from('bookings')
      .update({
        if (next == 'finished')
          'status': 'completed'
        else
          'journey_status': next,
        'work_notes': ?notes,
      })
      .eq('id', bookingId)
      .select()
      .single();

  @override
  Future<void> signOut() async {
    try {
      final p = await client
          .from('professionals')
          .select('id')
          .eq('user_id', client.auth.currentUser!.id)
          .maybeSingle();
      if (p != null) {
        await client
            .from('worker_availability')
            .delete()
            .eq('professional_id', p['id']);
      }
      await client
          .from('worker_locations')
          .delete()
          .neq('booking_id', '00000000-0000-0000-0000-000000000000');
    } catch (_) {
      /* Any old point expires after two minutes. */
    }
    await client.auth.signOut(scope: SignOutScope.local);
  }

  @override
  Stream<void> get jobChanges async* {
    final p = await client
        .from('professionals')
        .select('id')
        .eq('user_id', client.auth.currentUser!.id)
        .maybeSingle();
    if (p == null) return;
    yield* client
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('professional_id', p['id'])
        .map((_) {});
  }
}

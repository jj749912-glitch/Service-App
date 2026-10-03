import 'package:supabase_flutter/supabase_flutter.dart';

class ProviderSnapshot {
  final Map<String, dynamic>? professional, review;
  final List<Map<String, dynamic>> jobs;
  const ProviderSnapshot({
    this.professional,
    this.review,
    this.jobs = const [],
  });
}

abstract class ProviderApi {
  String get name;
  Future<ProviderSnapshot> load();
  Future<void> apply(Map<String, dynamic> fields);
  Future<void> change(String bookingId, String status);
  Future<void> signOut();
}

class SupabaseProviderApi implements ProviderApi {
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
        .from('professionals')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();
    final decision = p == null ? null : await client.rpc('my_worker_review');
    final jobs = p?['verified'] != true
        ? <Map<String, dynamic>>[]
        : await client
              .from('bookings')
              .select()
              .eq('professional_id', p!['id'])
              .order('starts_at');
    return ProviderSnapshot(
      professional: p,
      review: decision == null ? null : Map<String, dynamic>.from(decision),
      jobs: jobs,
    );
  }

  @override
  Future<void> apply(Map<String, dynamic> fields) async {
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Sign in to continue.');
    await client.from('professionals').insert({...fields, 'user_id': user.id});
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

  @override
  Future<void> signOut() => client.auth.signOut(scope: SignOutScope.local);
}

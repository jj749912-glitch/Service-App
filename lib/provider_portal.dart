import 'locations.dart';
import 'worker_approval_notice.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProviderPortal extends StatefulWidget {
  const ProviderPortal({super.key});
  @override
  State<ProviderPortal> createState() => _ProviderPortalState();
}

class _ProviderPortalState extends State<ProviderPortal> {
  final client = Supabase.instance.client;
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      rate = TextEditingController(),
      years = TextEditingController(),
      bio = TextEditingController();
  String service = 'Solar cleaning', city = initialCity;
  Map<String, dynamic>? professional;
  Map<String, dynamic>? review;
  List<Map<String, dynamic>> jobs = [];
  bool busy = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    name.dispose();
    rate.dispose();
    years.dispose();
    bio.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final p = await client
          .from('professionals')
          .select()
          .eq('user_id', client.auth.currentUser!.id)
          .maybeSingle();
      final decision = p == null ? null : await client.rpc('my_worker_review');
      final rows = p == null || p['verified'] != true
          ? <Map<String, dynamic>>[]
          : await client
                .from('bookings')
                .select()
                .eq('professional_id', p['id'])
                .order('starts_at');
      if (mounted) {
        setState(() {
          professional = p;
          review = decision == null
              ? null
              : Map<String, dynamic>.from(decision);
          jobs = rows;
          busy = false;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          professional = null;
          review = null;
          jobs = [];
          error = 'Could not load your workspace. Please retry.';
        });
      }
    }
  }

  Future<void> change(Map<String, dynamic> job, String status) async {
    setState(() => busy = true);
    try {
      await client
          .from('bookings')
          .update({'status': status})
          .eq('id', job['id']);
      await load();
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error =
              'Could not update this job. Completion is available after the scheduled service ends.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Professional workspace'),
      actions: [
        IconButton(
          onPressed: busy ? null : load,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh approval status',
        ),
      ],
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (busy) const LinearProgressIndicator(),
              if (error != null) ...[
                Text(error!, style: const TextStyle(color: Colors.red)),
                TextButton(onPressed: load, child: const Text('Retry')),
              ],
              if (!busy && error == null && professional == null)
                Form(
                  key: form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bring your skills to the neighbourhood.',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Apply as a professional. Your profile becomes bookable after an administrator verifies your identity and qualifications.',
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: name,
                        maxLength: 100,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                        ),
                        validator: (v) => (v?.trim().length ?? 0) < 3
                            ? 'Enter your full name'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: service,
                        decoration: const InputDecoration(
                          labelText: 'Primary service',
                        ),
                        items:
                            [
                                  'Solar cleaning',
                                  'Solar inspection',
                                  'Solar repair',
                                  'Electrical',
                                  'Plumbing',
                                  'Home cleaning',
                                ]
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) => service = v!,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: city,
                        decoration: const InputDecoration(
                          labelText: 'Service city',
                        ),
                        items: serviceCities
                            .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)),
                            )
                            .toList(),
                        onChanged: (v) => city = v!,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: rate,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Hourly labour rate (₹)',
                        ),
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          return n == null || n < 1 || n > 100000
                              ? 'Enter a rate between ₹1 and ₹100,000'
                              : null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: years,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Years of experience',
                        ),
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          return n == null || n < 0 || n > 60
                              ? 'Enter 0–60 years'
                              : null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: bio,
                        maxLines: 3,
                        maxLength: 2000,
                        decoration: const InputDecoration(
                          labelText: 'Tell customers about your skills',
                        ),
                        validator: (v) => (v?.trim().length ?? 0) < 20
                            ? 'Write at least 20 characters'
                            : null,
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () async {
                          if (!form.currentState!.validate()) return;
                          setState(() => busy = true);
                          try {
                            await client.from('professionals').insert({
                              'user_id': client.auth.currentUser!.id,
                              'name': name.text.trim(),
                              'service': service,
                              'city': city,
                              'hourly_rate': int.parse(rate.text),
                              'years': int.parse(years.text),
                              'bio': bio.text.trim(),
                            });
                            await load();
                          } catch (_) {
                            if (mounted) {
                              setState(() {
                                busy = false;
                                error =
                                    'Application could not be saved. Retry to check whether it was received.';
                              });
                            }
                          }
                        },
                        child: const Text('Submit application'),
                      ),
                    ],
                  ),
                ),
              if (!busy && error == null && professional != null) ...[
                Text(
                  professional!['name'],
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "${professional!['service']} · ₹${professional!['hourly_rate']}/hour",
                ),
                const SizedBox(height: 16),
                if (professional!['verified'] != true)
                  WorkerApprovalNotice(
                    status: review?['status'] as String? ?? 'pending',
                    note: review?['note'] as String? ?? '',
                  ),
                if (professional!['verified'] == true) ...[
                  const Text(
                    'Your service requests',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  if (jobs.isEmpty)
                    const Text('New customer requests will appear here.'),
                  ...jobs.map((job) {
                    final start = DateTime.parse(job['starts_at']).toLocal();
                    final ended = DateTime.parse(
                      job['ends_at'],
                    ).isBefore(DateTime.now());
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${job['service']} · ${job['status']}",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '${start.day}/${start.month}/${start.year} at ${start.hour}:00',
                            ),
                            Text(job['address']),
                            if ((job['notes'] as String).isNotEmpty)
                              Text(job['notes']),
                            Text("${job['hours']} hour(s) · ₹${job['total']}"),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              children: [
                                if (job['status'] == 'requested') ...[
                                  FilledButton(
                                    onPressed: busy
                                        ? null
                                        : () => change(job, 'accepted'),
                                    child: const Text('Accept'),
                                  ),
                                  OutlinedButton(
                                    onPressed: busy
                                        ? null
                                        : () => change(job, 'cancelled'),
                                    child: const Text('Decline'),
                                  ),
                                ],
                                if (job['status'] == 'accepted')
                                  FilledButton(
                                    onPressed: busy || !ended
                                        ? null
                                        : () => change(job, 'completed'),
                                    child: Text(
                                      ended
                                          ? 'Mark completed'
                                          : 'Complete after service ends',
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

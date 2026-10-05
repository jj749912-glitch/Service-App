import 'dart:async';
import 'service_offering.dart';
import 'worker_tracking.dart';
import 'worker_dashboard.dart';
import 'tracking.dart';
import 'mobile/customer_data.dart' show formatTime;
import 'locations.dart';
import 'worker_approval_notice.dart';
import 'provider_data.dart';
import 'mobile/components.dart';
import 'mobile/design.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProviderPortal extends StatefulWidget {
  final ProviderApi? api;
  final String? assetPackage;
  const ProviderPortal({super.key, this.api, this.assetPackage});
  @override
  State<ProviderPortal> createState() => _ProviderPortalState();
}

class _ProviderPortalState extends State<ProviderPortal> {
  late final ProviderApi api;
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      qualification = TextEditingController(),
      phone = TextEditingController();
  String savedPhone = '';
  List<ServiceOffering> offerings = [];
  String city = initialCity;
  Map<String, dynamic>? professional;
  Map<String, dynamic>? review;
  List<Map<String, dynamic>> jobs = [];
  bool busy = true;
  String? error;
  Timer? approvalRefresh;
  StreamSubscription<void>? jobChanges;
  @override
  void initState() {
    super.initState();
    api = widget.api ?? SupabaseProviderApi(Supabase.instance.client);
    name.text = api.name;
    if (api is WorkerUpdatesApi) {
      jobChanges = (api as WorkerUpdatesApi).jobChanges.listen((_) {
        if (mounted && !busy) load();
      }, onError: (_) {});
    }
    load();
    approvalRefresh = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!busy && mounted) load();
    });
  }

  @override
  void dispose() {
    approvalRefresh?.cancel();
    jobChanges?.cancel();
    name.dispose();
    qualification.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final snapshot = await api.load();
      if (mounted) {
        setState(() {
          professional = snapshot.professional;
          savedPhone = snapshot.phone;
          if (qualification.text.isEmpty) {
            qualification.text = snapshot.qualification;
          }
          review = snapshot.review;
          jobs = snapshot.jobs;
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
      await api.change(job['id'] as String, status);
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
  Widget build(BuildContext context) {
    if (professional?['verified'] == true) {
      return WorkerDashboard(
        professional: professional!,
        jobs: jobs,
        api: api,
        phone: savedPhone,
        onRefresh: load,
        liveEnabled: widget.api == null,
        assetPackage: widget.assetPackage,
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const ServeBrand(worker: true, size: 22),
        toolbarHeight: 78,
        flexibleSpace: SolarBackdrop(
          assetPackage: widget.assetPackage,
          height: 130,
          child: const SizedBox.expand(),
        ),
        actions: [
          IconButton(
            onPressed: busy ? null : load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh approval status',
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              try {
                await api.signOut();
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not sign out. Please retry.'),
                    ),
                  );
                }
              }
            },
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
                const Text(
                  'Professional Workspace',
                  style: TextStyle(
                    color: serveNavy,
                    fontSize: 23,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your profile, approval and service requests.',
                  style: TextStyle(color: serveMuted),
                ),
                const SizedBox(height: 20),
                if (busy) const LinearProgressIndicator(),
                if (error != null) ...[
                  Text(error!, style: const TextStyle(color: serveError)),
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
                        TextFormField(
                          controller: qualification,
                          maxLength: 2000,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Qualification',
                          ),
                          validator: (v) => (v?.trim().length ?? 0) < 2
                              ? 'Enter your qualification'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: phone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone number',
                            prefixText: '+91 ',
                            helperText:
                                'Shown to your assigned customer on the appointment day.',
                          ),
                          validator: (v) =>
                              RegExp(
                                r'^[6-9][0-9]{9}$',
                              ).hasMatch(v?.trim() ?? '')
                              ? null
                              : 'Enter your 10-digit Indian mobile number',
                        ),
                        const SizedBox(height: 16),
                        ServiceApplicationFields(
                          onChanged: (value) => offerings = value,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: city,
                          decoration: const InputDecoration(
                            labelText: 'Service city',
                          ),
                          items: serviceCities
                              .map(
                                (s) =>
                                    DropdownMenuItem(value: s, child: Text(s)),
                              )
                              .toList(),
                          onChanged: (v) => city = v!,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () async {
                            if (!form.currentState!.validate()) return;
                            setState(() => busy = true);
                            try {
                              await api.apply({
                                'name': name.text.trim(),
                                'service': offerings.first.service,
                                'services': offerings
                                    .map((s) => s.toJson())
                                    .toList(),
                                'qualification': qualification.text.trim(),
                                'phone': '+91${phone.text.trim()}',
                                'city': city,
                                'hourly_rate': offerings.first.rate,
                                'years': offerings.first.years,
                                'bio': offerings.first.details,
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
                  Text(
                    'Qualification: ${professional!['qualification'] ?? 'Not supplied'}',
                  ),
                  for (final item in (professional!['services'] as List? ?? []))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${item['service']} · ₹${item['hourly_rate']}/hour',
                      ),
                      subtitle: Text(
                        '${item['years']} years · ${item['details']}',
                      ),
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
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
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
                                '${start.day}/${start.month}/${start.year} at ${formatTime(start)}',
                              ),
                              Text(job['address']),
                              if (job['status'] == 'accepted' &&
                                  widget.api == null)
                                WorkerTrackingControl(
                                  key: ValueKey(job['id']),
                                  booking: job,
                                ),
                              if ((job['notes'] as String).isNotEmpty)
                                Text(job['notes']),
                              Text(
                                "${job['hours']} hour(s) · ₹${job['total']}",
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                children: [
                                  if (job['status'] == 'requested') ...[
                                    FilledButton(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: serveYellow,
                                        foregroundColor: serveNavy,
                                      ),
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
}

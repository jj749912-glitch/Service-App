import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'provider_data.dart';
import 'tracking.dart';
import 'worker_tracking.dart';
import 'mobile/components.dart';
import 'mobile/customer_data.dart';
import 'mobile/design.dart';
import 'mobile/location_map.dart';
import 'booking_chat.dart';

class WorkerDashboard extends StatefulWidget {
  final Map<String, dynamic> professional;
  final List<Map<String, dynamic>> jobs;
  final ProviderApi api;
  final String phone;
  final VoidCallback onRefresh;
  final bool liveEnabled;
  final String? assetPackage;
  const WorkerDashboard({
    super.key,
    required this.professional,
    required this.jobs,
    required this.api,
    required this.phone,
    required this.onRefresh,
    required this.liveEnabled,
    this.assetPackage,
  });
  @override
  State<WorkerDashboard> createState() => _WorkerDashboardState();
}

class _WorkerDashboardState extends State<WorkerDashboard> {
  int tab = 0;
  String filter = 'requested';
  bool busy = false;
  String? error;
  Future<void> decision(Map<String, dynamic> job, String status) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.change(job['id'] as String, status);
      widget.onRefresh();
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Could not save the decision. Refresh and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> details(Map<String, dynamic> job) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WorkerJobDetails(
          booking: job,
          api: widget.api,
          onRefresh: widget.onRefresh,
          liveEnabled: widget.liveEnabled,
        ),
      ),
    );
    widget.onRefresh();
  }

  Widget jobCard(Map<String, dynamic> job) {
    final start = DateTime.parse(job['starts_at'] as String).toLocal();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ServeCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ServiceArt(
                  job['service'] as String,
                  size: 58,
                  assetPackage: widget.assetPackage,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayService(job['service'] as String),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        job['address'] as String,
                        style: const TextStyle(color: serveMuted, fontSize: 11),
                      ),
                      Text(
                        '${formatDate(start)} · ${formatTime(start)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    bookingStatus(job),
                    style: const TextStyle(color: serveBlue),
                  ),
                ),
                Text(
                  '₹${job['total']}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (job['status'] == 'requested')
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : () => decision(job, 'cancelled'),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: busy ? null : () => decision(job, 'accepted'),
                      child: const Text('Accept'),
                    ),
                  ),
                ],
              ),
            OutlinedButton(
              onPressed: () => details(job),
              child: const Text('View Details'),
            ),
          ],
        ),
      ),
    );
  }

  Widget home() {
    final now = DateTime.now();
    final today = widget.jobs.where((j) {
      final d = DateTime.parse(j['starts_at'] as String).toLocal();
      return d.year == now.year &&
          d.month == now.month &&
          d.day == now.day &&
          j['status'] != 'cancelled';
    }).toList();
    final completed = today
        .where((j) => j['status'] == 'completed')
        .fold<num>(0, (v, j) => v + (j['total'] as num));
    final upcoming = widget.jobs
        .where((j) => j['status'] == 'accepted')
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(child: Icon(Icons.engineering)),
          title: Text(
            widget.professional['name'] as String,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 22),
          ),
          subtitle: Text(
            displayService(widget.professional['service'] as String),
          ),
        ),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00A6C3), Color(0xFF008D78)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              metric('${today.length}', 'Today’s jobs'),
              metric('₹$completed', 'Completed labour'),
              metric(
                (widget.professional['review_count'] as num? ?? 0) == 0
                    ? 'New'
                    : '${widget.professional['rating']}',
                'Rating',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SolarBackdrop(
          height: 150,
          assetPackage: widget.assetPackage,
          child: const Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'More Jobs\nMore Opportunities',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 22,
                  ),
                ),
                Text(
                  'Go online to appear to nearby customers.',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const CareSection('Upcoming Jobs'),
        if (upcoming.isEmpty)
          const EmptyCare(
            icon: Icons.event_note,
            title: 'No confirmed jobs yet',
            message: 'Accepted appointments will appear here.',
          ),
        ...upcoming.map(jobCard),
      ],
    );
  }

  Widget metric(String value, String label) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 22,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 10),
        ),
      ],
    ),
  );
  Widget jobs() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const CareSection('My Jobs'),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final f in [
              ('requested', 'New'),
              ('accepted', 'Accepted'),
              ('completed', 'Completed'),
              ('cancelled', 'Declined / Cancelled'),
            ])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    '${f.$2} (${widget.jobs.where((j) => j['status'] == f.$1).length})',
                  ),
                  selected: filter == f.$1,
                  onSelected: (_) => setState(() => filter = f.$1),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      if (!widget.jobs.any((j) => j['status'] == filter))
        const EmptyCare(
          icon: Icons.work_outline,
          title: 'No jobs in this list',
          message: 'Your actual customer appointments will appear here.',
        ),
      ...widget.jobs.where((j) => j['status'] == filter).map(jobCard),
    ],
  );
  Widget earnings() {
    final done = widget.jobs.where((j) => j['status'] == 'completed').toList();
    final total = done.fold<num>(0, (v, j) => v + (j['total'] as num));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CareSection('Earnings & Work'),
        ServeCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Completed job labour value'),
              Text(
                '₹$total',
                style: const TextStyle(
                  fontSize: 35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Text(
                'Booking estimates only. Payments and wallet payouts are not recorded in this app.',
                style: TextStyle(color: serveMuted, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ...done.map(jobCard),
      ],
    );
  }

  Future<void> editPhone() async {
    final controller = TextEditingController(
      text: widget.phone.replaceFirst('+91', ''),
    );
    final form = GlobalKey<FormState>();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Worker Contact'),
        content: Form(
          key: form,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone number',
              prefixText: '+91 ',
            ),
            validator: (v) =>
                RegExp(r'^[6-9][0-9]{9}$').hasMatch(v?.trim() ?? '')
                ? null
                : 'Enter a 10-digit mobile number',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(ctx, '+91${controller.text.trim()}');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    // The dialog route may still be animating when it returns.
    if (value != null && widget.liveEnabled) {
      try {
        await Supabase.instance.client.rpc(
          'save_worker_phone',
          params: {'p_phone': value},
        );
        widget.onRefresh();
      } catch (_) {
        if (mounted) {
          setState(
            () => error = 'Phone number could not be saved. Please retry.',
          );
        }
      }
    }
  }

  Widget profile() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const CareSection('Professional Profile'),
      ServeCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.professional['name'] as String,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
            ),
            Text(
              'Qualification: ${widget.professional['qualification'] ?? 'Not supplied'}',
            ),
            Text('Service city: ${widget.professional['city']}'),
            Text(
              'Completed jobs: ${widget.jobs.where((j) => j['status'] == 'completed').length}',
            ),
            Text('Reviews: ${widget.professional['review_count'] ?? 0}'),
            Text(
              'Phone: ${widget.phone.isEmpty ? 'Not supplied' : widget.phone}',
            ),
            const Text(
              'Your assigned customer can view your number only on the confirmed appointment day.',
              style: TextStyle(color: serveMuted, fontSize: 12),
            ),
            OutlinedButton(
              onPressed: widget.liveEnabled ? editPhone : null,
              child: Text(
                widget.phone.isEmpty ? 'Add Phone Number' : 'Edit Phone Number',
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      const CareSection('Services Offered'),
      for (final s in (widget.professional['services'] as List? ?? []))
        ServeCard(
          child: ListTile(
            title: Text(
              '${displayService(s['service'] as String)} · ₹${s['hourly_rate']}/hr',
            ),
            subtitle: Text('${s['years']} years\n${s['details']}'),
          ),
        ),
    ],
  );
  Widget messages() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const CareSection('Messages'),
      if (!widget.jobs.any(
        (j) => ['accepted', 'completed'].contains(j['status']),
      ))
        const EmptyCare(
          icon: Icons.chat_bubble_outline,
          title: 'No confirmed conversations yet',
          message: 'You can message customers after accepting their booking.',
        ),
      for (final j in widget.jobs.where(
        (j) => ['accepted', 'completed'].contains(j['status']),
      ))
        ServeCard(
          child: ListTile(
            leading: const Icon(Icons.chat_bubble_outline, color: serveBlue),
            title: Text(displayService(j['service'] as String)),
            subtitle: Text(j['address'] as String),
            trailing: const Icon(Icons.chevron_right),
            onTap: widget.liveEnabled
                ? () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => BookingChat(booking: j),
                    ),
                  )
                : null,
          ),
        ),
    ],
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const ServeBrand(worker: true, size: 23),
      actions: [
        IconButton(
          onPressed: widget.onRefresh,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
        ),
        IconButton(
          onPressed: () async {
            try {
              await widget.api.signOut();
            } catch (_) {
              if (mounted) {
                setState(() => error = 'Could not sign out. Please retry.');
              }
            }
          },
          icon: const Icon(Icons.logout),
          tooltip: 'Sign out',
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (busy) const LinearProgressIndicator(),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
              if (widget.liveEnabled)
                WorkerTrackingControl.availability(
                  key: ValueKey('availability-${widget.professional['id']}'),
                  professionalId: widget.professional['id'] as String,
                ),
              [home, jobs, earnings, messages, profile][tab](),
            ],
          ),
        ),
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (v) => setState(() => tab = v),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.work_outline), label: 'Jobs'),
        NavigationDestination(
          icon: Icon(Icons.account_balance_wallet_outlined),
          label: 'Earnings',
        ),
        NavigationDestination(
          icon: Icon(Icons.chat_bubble_outline),
          label: 'Messages',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Profile',
        ),
      ],
    ),
  );
}

class WorkerJobDetails extends StatefulWidget {
  final Map<String, dynamic> booking;
  final ProviderApi api;
  final VoidCallback onRefresh;
  final bool liveEnabled;
  const WorkerJobDetails({
    super.key,
    required this.booking,
    required this.api,
    required this.onRefresh,
    required this.liveEnabled,
  });
  @override
  State<WorkerJobDetails> createState() => _WorkerJobDetailsState();
}

class _WorkerJobDetailsState extends State<WorkerJobDetails> {
  late Map<String, dynamic> job;
  final notes = TextEditingController();
  Timer? timer;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    job = Map.of(widget.booking);
    notes.text = job['work_notes'] as String? ?? '';
    timer = Timer.periodic(const Duration(seconds: 15), (_) => reload());
  }

  @override
  void dispose() {
    timer?.cancel();
    notes.dispose();
    super.dispose();
  }

  Future<void> reload() async {
    try {
      final data = await widget.api.load();
      final row = data.jobs.where((j) => j['id'] == job['id']).firstOrNull;
      if (mounted && row != null) setState(() => job = Map.of(row));
    } catch (_) {
      if (mounted) setState(() => error = 'Could not refresh this job.');
    }
  }

  Future<void> milestone(String next) async {
    if (widget.api is! SupabaseProviderApi) return;
    if (next == 'finished') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Complete This Job?'),
          content: const Text(
            'Confirm that the actual service has been completed. The customer will be notified and can review this booking.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep Working'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Submit Completion'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await (widget.api as SupabaseProviderApi).milestone(
        job['id'] as String,
        next,
        notes: notes.text.trim(),
      );
      if (mounted) setState(() => job = Map.of(result));
      widget.onRefresh();
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'This step could not be saved. Refresh and check that the appointment is confirmed and within its allowed time.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> decision(String status) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.change(job['id'] as String, status);
      await reload();
      widget.onRefresh();
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'The decision was not saved. Refresh and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final point =
        job['customer_latitude'] == null || job['customer_longitude'] == null
        ? null
        : LatLng(
            (job['customer_latitude'] as num).toDouble(),
            (job['customer_longitude'] as num).toDouble(),
          );
    final phase = job['journey_status'] as String? ?? 'not_started';
    final start = DateTime.parse(job['starts_at'] as String).toLocal();
    return Scaffold(
      appBar: AppBar(title: const Text('Job Details')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ServeCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ServiceArt(job['service'] as String, size: 70),
                      Text(
                        displayService(job['service'] as String),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text('Booking ${job['id']}'),
                      Text(bookingStatus(job)),
                      Text('${formatDate(start)} · ${formatTime(start)}'),
                      Text(
                        'Duration: ${job['duration_minutes'] ?? ((job['hours'] as num) * 60).round()} minutes',
                      ),
                      Text(job['address'] as String),
                      if ((job['notes'] as String? ?? '').isNotEmpty)
                        Text('Customer notes: ${job['notes']}'),
                      Text('Labour estimate: ₹${job['total']}'),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (job['status'] == 'requested')
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: busy ? null : () => decision('cancelled'),
                          child: const Text('Decline'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: busy ? null : () => decision('accepted'),
                          child: const Text('Accept'),
                        ),
                      ),
                    ],
                  ),
                if (job['status'] == 'accepted') ...[
                  Text(
                    'Progress: ${{'not_started': 'Confirmed', 'on_way': 'On the Way', 'arrived': 'Arrived', 'in_progress': 'Work in Progress', 'finished': 'Completed'}[phase]}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (point != null) ...[
                    SizedBox(
                      height: 300,
                      child: LocationMap(
                        center: point,
                        pins: [
                          LocationPin('customer', 'Customer Location', point),
                        ],
                        enabled: widget.liveEnabled,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final opened = await launchUrl(
                          Uri.https('www.google.com', '/maps/dir/', {
                            'api': '1',
                            'destination':
                                '${point.latitude},${point.longitude}',
                          }),
                          mode: LaunchMode.externalApplication,
                        );
                        if (!opened && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Could not open navigation. Use the service address above.',
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.navigation_outlined),
                      label: const Text('Open in Maps'),
                    ),
                  ],
                  if (widget.liveEnabled)
                    WorkerTrackingControl(
                      key: ValueKey(job['id']),
                      booking: job,
                    ),
                  if (phase == 'not_started')
                    FilledButton(
                      onPressed:
                          busy || !trackingWindowOpen(job, DateTime.now())
                          ? null
                          : () => milestone('on_way'),
                      child: const Text('Start Journey'),
                    ),
                  if (phase == 'not_started')
                    Text(trackingAvailability(job, DateTime.now())),
                  if (phase == 'on_way')
                    FilledButton(
                      onPressed: busy ? null : () => milestone('arrived'),
                      child: const Text('I Have Arrived'),
                    ),
                  if (phase == 'arrived')
                    FilledButton(
                      onPressed: busy ? null : () => milestone('in_progress'),
                      child: const Text('Start Job'),
                    ),
                  if (phase == 'in_progress') ...[
                    TextFormField(
                      controller: notes,
                      maxLines: 4,
                      maxLength: 4000,
                      decoration: const InputDecoration(
                        labelText: 'Actual work notes',
                      ),
                    ),
                    FilledButton(
                      onPressed: busy ? null : () => milestone('finished'),
                      child: const Text('Complete Job'),
                    ),
                  ],
                ],
                if (job['status'] == 'completed')
                  ServeCard(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 60,
                        ),
                        const Text(
                          'Job Completed',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 24,
                          ),
                        ),
                        const Text(
                          'The customer can now review this completed service.',
                        ),
                        if ((job['work_notes'] as String? ?? '').isNotEmpty)
                          Text(job['work_notes'] as String),
                      ],
                    ),
                  ),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
                OutlinedButton(
                  onPressed: reload,
                  child: const Text('Refresh Job'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

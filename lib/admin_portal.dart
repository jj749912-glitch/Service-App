import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'locations.dart';

/// Injectable boundary keeps widget tests isolated from real accounts and data.
abstract class AdminApi {
  Future<bool> hasAccess();
  Future<Map<String, dynamic>> summary();
  Future<Map<String, dynamic>> list(String section, String status, int offset);
  Future<void> review(
    Map<String, dynamic> worker,
    String status,
    String note,
    bool checked,
  );
  Future<void> updateProfile(
    String id,
    Map<String, dynamic> profile,
    String note,
  );
  Future<void> cancelBooking(String id, String note);
}

class SupabaseAdminApi implements AdminApi {
  final SupabaseClient client;
  SupabaseAdminApi(this.client);
  @override
  Future<bool> hasAccess() async =>
      client.auth.currentSession != null &&
      await client.rpc('is_app_admin') == true;
  @override
  Future<Map<String, dynamic>> summary() async =>
      Map<String, dynamic>.from(await client.rpc('admin_summary'));
  @override
  Future<Map<String, dynamic>> list(
    String section,
    String status,
    int offset,
  ) async => Map<String, dynamic>.from(
    await client.rpc(
      'admin_list',
      params: {'p_section': section, 'p_status': status, 'p_offset': offset},
    ),
  );
  @override
  Future<void> review(
    Map<String, dynamic> worker,
    String status,
    String note,
    bool checked,
  ) async {
    await client.rpc(
      'admin_review_worker',
      params: {
        'p_id': worker['id'],
        'p_status': status,
        'p_note': note,
        'p_expected_status': worker['approval_status'],
        'p_checks_confirmed': checked,
      },
    );
  }

  @override
  Future<void> updateProfile(
    String id,
    Map<String, dynamic> profile,
    String note,
  ) async {
    await client.rpc(
      'admin_update_worker',
      params: {'p_id': id, 'p_profile': profile, 'p_note': note},
    );
  }

  @override
  Future<void> cancelBooking(String id, String note) async {
    await client.rpc(
      'admin_cancel_booking',
      params: {'p_id': id, 'p_note': note},
    );
  }
}

class AdminPortal extends StatefulWidget {
  final AdminApi? api;
  const AdminPortal({super.key, this.api});
  @override
  State<AdminPortal> createState() => _AdminPortalState();
}

class _AdminPortalState extends State<AdminPortal> {
  late final AdminApi api;
  StreamSubscription<AuthState>? authChanges;
  bool loading = true, allowed = false;
  String? error;
  String section = 'workers', status = 'pending';
  int offset = 0, total = 0, request = 0;
  Map<String, dynamic> counts = {};
  List<Map<String, dynamic>> rows = [];

  @override
  void initState() {
    super.initState();
    api = widget.api ?? SupabaseAdminApi(Supabase.instance.client);
    if (widget.api == null) {
      authChanges = Supabase.instance.client.auth.onAuthStateChange.listen((
        event,
      ) {
        if (event.event == AuthChangeEvent.signedOut && mounted) {
          request++;
          setState(() {
            allowed = false;
            loading = false;
            rows = [];
            counts = {};
          });
        }
      });
    }
    load();
  }

  @override
  void dispose() {
    authChanges?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    final current = ++request;
    setState(() {
      loading = true;
      error = null;
      rows = [];
    });
    try {
      final access = await api.hasAccess();
      if (!mounted || current != request) return;
      if (!access) {
        setState(() {
          allowed = false;
          loading = false;
          counts = {};
        });
        return;
      }
      final overview = await api.summary();
      final page = await api.list(section, status, offset);
      if (!mounted || current != request) return;
      setState(() {
        allowed = true;
        counts = overview;
        rows = (page['items'] as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
        total = (page['total'] as num).toInt();
        loading = false;
      });
    } catch (e) {
      if (!mounted || current != request) return;
      setState(() {
        loading = false;
        rows = [];
        error = adminError(e);
      });
    }
  }

  void switchSection(String value) {
    setState(() {
      section = value;
      status = value == 'workers' ? 'pending' : 'all';
      offset = 0;
    });
    load();
  }

  Future<void> reviewWorker(
    Map<String, dynamic> worker,
    String decision,
  ) async {
    final approved = decision == 'approved';
    await showDialog<void>(
      context: context,
      builder: (context) => AdminActionDialog(
        title:
            '${approved
                ? 'Approve'
                : decision == 'rejected'
                ? 'Reject'
                : 'Suspend'} ${worker['name']}',
        description: approved
            ? 'Approval makes this worker visible to customers and allows access to service requests.'
            : decision == 'suspended'
            ? 'This worker will be hidden from customers and lose access to service requests. Existing bookings remain active; review them in Bookings.'
            : 'This worker will stay hidden and cannot receive jobs. They will see your reason.',
        confirmLabel: approved
            ? 'Approve worker'
            : decision == 'rejected'
            ? 'Reject application'
            : 'Suspend worker',
        requireChecks: approved,
        onConfirm: (note, checked) =>
            api.review(worker, decision, note, checked),
      ),
    );
    if (mounted) await load();
  }

  Future<void> editWorker(Map<String, dynamic> worker) async {
    await showDialog<void>(
      context: context,
      builder: (context) => WorkerEditDialog(worker: worker, api: api),
    );
    if (mounted) await load();
  }

  Future<void> cancelBooking(Map<String, dynamic> booking) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AdminActionDialog(
        title: 'Cancel booking',
        description:
            'Cancel the ${booking['service']} booking with ${booking['professional_name']}? The customer and worker will see the cancelled status.',
        confirmLabel: 'Cancel booking',
        onConfirm: (note, _) =>
            api.cancelBooking(booking['id'] as String, note),
      ),
    );
    if (mounted) await load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Admin dashboard'),
      actions: [
        IconButton(
          onPressed: loading ? null : load,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh dashboard',
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (loading) const LinearProgressIndicator(),
            if (error != null) ...[
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              TextButton(
                onPressed: loading ? null : load,
                child: const Text('Retry'),
              ),
            ],
            if (!loading && !allowed && error == null) ...[
              const SizedBox(height: 60),
              const Icon(Icons.admin_panel_settings_outlined, size: 56),
              const SizedBox(height: 20),
              const Text(
                'Administrator access required',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Sign in with an account that the project owner has granted admin access.',
                textAlign: TextAlign.center,
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('Back to home'),
              ),
            ],
            if (allowed) ...[
              const Text(
                'Care starts with trust.',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Review workers, manage their profiles and oversee service bookings.',
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final metric in [
                    ('pending', 'Awaiting approval'),
                    ('approved', 'Approved workers'),
                    ('active_bookings', 'Active bookings'),
                    ('users', 'Registered users'),
                  ])
                    SizedBox(
                      width: 220,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${counts[metric.$1] ?? 0}',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(metric.$2),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in [
                    ('workers', 'Workers'),
                    ('bookings', 'Bookings'),
                    ('users', 'Users'),
                    ('activity', 'Activity'),
                  ])
                    ChoiceChip(
                      label: Text(item.$2),
                      selected: section == item.$1,
                      onSelected: loading
                          ? null
                          : (_) => switchSection(item.$1),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              if (section == 'workers' || section == 'bookings') ...[
                DropdownButtonFormField<String>(
                  key: ValueKey('$section:$status'),
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items:
                      (section == 'workers'
                              ? [
                                  'all',
                                  'pending',
                                  'approved',
                                  'rejected',
                                  'suspended',
                                ]
                              : [
                                  'all',
                                  'requested',
                                  'accepted',
                                  'completed',
                                  'cancelled',
                                ])
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(label(value)),
                            ),
                          )
                          .toList(),
                  onChanged: loading
                      ? null
                      : (value) {
                          setState(() {
                            status = value!;
                            offset = 0;
                          });
                          load();
                        },
                ),
                const SizedBox(height: 16),
              ],
              if (!loading && error == null && rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  child: Text(
                    section == 'workers'
                        ? 'No ${status == 'all' ? '' : '$status '}worker applications. Real applications will appear here.'
                        : 'No ${section == 'activity' ? 'admin activity' : section} to show.',
                  ),
                ),
              for (final row in rows) recordCard(row),
              if (!loading && total > 0)
                Wrap(
                  spacing: 14,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('${offset + 1}–${offset + rows.length} of $total'),
                    TextButton(
                      onPressed: offset == 0
                          ? null
                          : () {
                              offset -= 25;
                              load();
                            },
                      child: const Text('Previous'),
                    ),
                    TextButton(
                      onPressed: offset + rows.length >= total
                          ? null
                          : () {
                              offset += 25;
                              load();
                            },
                      child: const Text('Next'),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    ),
  );

  Widget recordCard(Map<String, dynamic> row) {
    final worker = section == 'workers';
    final state = row['approval_status'] as String? ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (worker) ...[
              Text(
                row['name'] as String,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text('${row['service']} · ${row['city']}'),
              Text(
                '₹${row['hourly_rate']}/hour · ${row['years']} years of experience',
              ),
              const SizedBox(height: 8),
              SelectableText(row['email'] as String? ?? 'No email'),
              Text(
                'Email ${row['email_confirmed'] == true ? 'confirmed' : 'not confirmed'} · ${label(state)}',
              ),
              const SizedBox(height: 12),
              Text(row['bio'] as String),
              Text('Qualification: ${row['qualification'] ?? 'Not supplied'}'),
              Text('Phone: ${row['phone'] ?? 'Not supplied'}'),
              for (final service in (row['services'] as List? ?? []))
                Text(
                  '${service['service']} · ₹${service['hourly_rate']}/hr · ${service['years']} years\n${service['details']}',
                ),
              Text('Qualification: ${row['qualification'] ?? 'Not supplied'}'),
              for (final offer in (row['services'] as List? ?? []))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${offer['service']} · ₹${offer['hourly_rate']}/hour',
                  ),
                  subtitle: Text(
                    '${offer['years']} years · ${offer['details']}',
                  ),
                ),

              if ((row['review_note'] as String? ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Last review: ${row['review_note']}'),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: loading ? null : () => editWorker(row),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit profile'),
                  ),
                  if (state != 'approved')
                    FilledButton(
                      onPressed: loading || row['email_confirmed'] != true
                          ? null
                          : () => reviewWorker(row, 'approved'),
                      child: Text(
                        state == 'suspended'
                            ? 'Restore access'
                            : 'Review & approve',
                      ),
                    ),
                  if (state == 'pending')
                    TextButton(
                      onPressed: loading
                          ? null
                          : () => reviewWorker(row, 'rejected'),
                      child: const Text('Reject'),
                    ),
                  if (state == 'approved')
                    OutlinedButton(
                      onPressed: loading
                          ? null
                          : () => reviewWorker(row, 'suspended'),
                      child: const Text('Suspend access'),
                    ),
                ],
              ),
            ] else if (section == 'bookings') ...[
              Text(
                '${row['service']} · ${label(row['status'] as String)}',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text('Worker: ${row['professional_name']}'),
              Text('Customer: ${row['customer_email']}'),
              Text(
                '${dateLabel(row['starts_at'])} · ${row['hours']} hour(s) · ₹${row['total']}',
              ),
              Text(row['address'] as String),
              if ((row['notes'] as String).isNotEmpty)
                Text(row['notes'] as String),
              if (row['worker_approved'] != true)
                const Text('Worker access is currently disabled.'),
              if (['requested', 'accepted'].contains(row['status']))
                TextButton(
                  onPressed: loading ? null : () => cancelBooking(row),
                  child: const Text('Cancel booking'),
                ),
            ] else if (section == 'users') ...[
              SelectableText(
                row['email'] as String? ?? 'No email',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${row['account_type']} · Email ${row['email_confirmed'] == true ? 'confirmed' : 'awaiting confirmation'}',
              ),
              Text('Joined ${dateLabel(row['created_at'])}'),
            ] else ...[
              Text(
                label((row['action'] as String).replaceAll('_', ' ')),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${row['actor_email'] ?? 'Former administrator'} · ${dateLabel(row['created_at'])}',
              ),
              Text('${row['details']['name'] ?? ''}'),
              Text('${row['details']['note'] ?? ''}'),
            ],
          ],
        ),
      ),
    );
  }
}

String label(String text) =>
    text.isEmpty ? '' : '${text[0].toUpperCase()}${text.substring(1)}';
String dateLabel(dynamic value) {
  final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  if (date == null) return 'Unknown date';
  return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

String adminError(Object error) =>
    error is PostgrestException && error.code == '42501'
    ? 'Administrator access is no longer available. Sign in with an authorized account.'
    : error is PostgrestException && error.code == 'P0001'
    ? error.message
    : 'Could not complete this request. Refresh and try again.';

class AdminActionDialog extends StatefulWidget {
  final String title, description, confirmLabel;
  final bool requireChecks;
  final Future<void> Function(String note, bool checked) onConfirm;
  const AdminActionDialog({
    super.key,
    required this.title,
    required this.description,
    required this.confirmLabel,
    required this.onConfirm,
    this.requireChecks = false,
  });
  @override
  State<AdminActionDialog> createState() => _AdminActionDialogState();
}

class _AdminActionDialogState extends State<AdminActionDialog> {
  final note = TextEditingController();
  final checks = [false, false, false];
  bool busy = false;
  String? error;
  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.description),
              const SizedBox(height: 16),
              if (widget.requireChecks) ...[
                for (var i = 0; i < checks.length; i++)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: checks[i],
                    onChanged: busy
                        ? null
                        : (value) => setState(() => checks[i] = value!),
                    title: Text(
                      [
                        'I verified the worker’s identity.',
                        'I verified the required skills and qualifications.',
                        'I confirmed the service area and hourly rate.',
                      ][i],
                    ),
                  ),
              ],
              TextField(
                controller: note,
                maxLength: 2000,
                maxLines: 3,
                enabled: !busy,
                decoration: const InputDecoration(
                  labelText: 'Reason / review note',
                  helperText: 'Worker review notes are visible to the worker.',
                ),
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Back'),
        ),
        FilledButton(
          onPressed: busy || (widget.requireChecks && checks.contains(false))
              ? null
              : () async {
                  if (note.text.trim().length < 5) {
                    setState(
                      () => error = 'Enter a reason of at least 5 characters.',
                    );
                    return;
                  }
                  setState(() {
                    busy = true;
                    error = null;
                  });
                  try {
                    await widget.onConfirm(
                      note.text.trim(),
                      checks.every((value) => value),
                    );
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    if (mounted) {
                      setState(() {
                        busy = false;
                        error = adminError(e);
                      });
                    }
                  }
                },
          child: Text(busy ? 'Saving…' : widget.confirmLabel),
        ),
      ],
    ),
  );
}

class WorkerEditDialog extends StatefulWidget {
  final Map<String, dynamic> worker;
  final AdminApi api;
  const WorkerEditDialog({super.key, required this.worker, required this.api});
  @override
  State<WorkerEditDialog> createState() => _WorkerEditDialogState();
}

class _WorkerEditDialogState extends State<WorkerEditDialog> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name, rate, years, bio;
  final note = TextEditingController();
  late String service, city;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.worker['name']);
    rate = TextEditingController(text: '${widget.worker['hourly_rate']}');
    years = TextEditingController(text: '${widget.worker['years']}');
    bio = TextEditingController(text: widget.worker['bio']);
    service = widget.worker['service'];
    city = widget.worker['city'];
  }

  @override
  void dispose() {
    for (final c in [name, rate, years, bio, note]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: const Text('Edit worker profile'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Profile changes appear to customers once the worker is approved. Existing booking prices stay the same.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: name,
                  enabled: !busy,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (value) => (value?.trim().length ?? 0) < 3
                      ? 'Enter at least 3 characters'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: service,
                  decoration: const InputDecoration(labelText: 'Service'),
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
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                  onChanged: busy ? null : (value) => service = value!,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: city,
                  decoration: const InputDecoration(labelText: 'City'),
                  items: serviceCities
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: busy ? null : (value) => city = value!,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: rate,
                  enabled: !busy,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Hourly rate (₹)',
                  ),
                  validator: (value) {
                    final n = int.tryParse(value ?? '');
                    return n == null || n < 1 || n > 100000
                        ? 'Enter ₹1–₹100,000'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: years,
                  enabled: !busy,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Years of experience',
                  ),
                  validator: (value) {
                    final n = int.tryParse(value ?? '');
                    return n == null || n < 0 || n > 60
                        ? 'Enter 0–60 years'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: bio,
                  enabled: !busy,
                  maxLength: 2000,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Profile description',
                  ),
                  validator: (value) => (value?.trim().length ?? 0) < 20
                      ? 'Enter at least 20 characters'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: note,
                  enabled: !busy,
                  maxLength: 2000,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Reason for this change',
                  ),
                  validator: (value) => (value?.trim().length ?? 0) < 5
                      ? 'Enter at least 5 characters'
                      : null,
                ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Back'),
        ),
        FilledButton(
          onPressed: busy
              ? null
              : () async {
                  if (!form.currentState!.validate()) return;
                  setState(() {
                    busy = true;
                    error = null;
                  });
                  try {
                    await widget.api.updateProfile(widget.worker['id'], {
                      'name': name.text.trim(),
                      'service': service,
                      'city': city,
                      'hourly_rate': int.parse(rate.text),
                      'years': int.parse(years.text),
                      'bio': bio.text.trim(),
                    }, note.text.trim());
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    if (mounted) {
                      setState(() {
                        busy = false;
                        error = adminError(e);
                      });
                    }
                  }
                },
          child: Text(busy ? 'Saving…' : 'Save profile'),
        ),
      ],
    ),
  );
}

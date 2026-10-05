import 'dart:math';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../app.dart' show Professional;
import 'components.dart';
import 'customer_data.dart';
import 'design.dart';

abstract class MultiServiceBookingApi {
  Future<List<Map<String, dynamic>>> bookServices({
    required String requestId,
    required DateTime start,
    required String address,
    required String notes,
    required LatLng location,
    required List<Map<String, dynamic>> requests,
  });
}

String newBookingRequestId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

String bookingServicesLabel(Map<String, dynamic> booking) {
  final items = booking['service_items'] as List? ?? [];
  return items.isEmpty
      ? displayService(booking['service'] as String)
      : items.map((i) => displayService(i['service'] as String)).join(' + ');
}

class BookingServiceLines extends StatelessWidget {
  final Map<String, dynamic> booking;
  const BookingServiceLines(this.booking, {super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final item in booking['service_items'] as List? ?? [])
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '${displayService(item['service'] as String)} · ${item['duration_minutes']} min · ₹${item['hourly_rate']}/hr · ₹${item['total']}',
          ),
        ),
    ],
  );
}

/// Each worker receives one appointment containing their assigned services.
class MultiServiceSchedulePage extends StatefulWidget {
  final MultiServiceBookingApi api;
  final Map<String, Professional> assignments;
  final String address;
  final LatLng location;
  const MultiServiceSchedulePage({
    super.key,
    required this.api,
    required this.assignments,
    required this.address,
    required this.location,
  });
  @override
  State<MultiServiceSchedulePage> createState() =>
      _MultiServiceSchedulePageState();
}

class _MultiServiceSchedulePageState extends State<MultiServiceSchedulePage> {
  final form = GlobalKey<FormState>();
  final time = TextEditingController(text: '09:00');
  final notes = TextEditingController();
  late final Map<String, TextEditingController> durations;
  late DateTime day;
  bool busy = false;
  String? error;
  String requestId = newBookingRequestId(), fingerprint = '';
  int hour = 9, minute = 0;
  @override
  void initState() {
    super.initState();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    day = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    durations = {
      for (final service in widget.assignments.keys)
        service: TextEditingController(text: '60'),
    };
  }

  @override
  void dispose() {
    for (final controller in [time, notes, ...durations.values]) {
      controller.dispose();
    }
    super.dispose();
  }

  int minutes(String service) => int.tryParse(durations[service]!.text) ?? 0;
  int price(String service) =>
      (widget.assignments[service]!.forService(service).rate *
              minutes(service) /
              60)
          .ceil();
  int get estimate =>
      widget.assignments.keys.fold(0, (sum, service) => sum + price(service));
  List<Map<String, dynamic>> get requests {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final entry in widget.assignments.entries) {
      (groups[entry.value.id] ??= []).add({
        'service': entry.key,
        'duration_minutes': minutes(entry.key),
      });
    }
    return groups.entries
        .map(
          (g) => <String, dynamic>{
            'professional_id': g.key,
            'services': g.value,
          },
        )
        .toList();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final start = DateTime(day.year, day.month, day.day, hour, minute);
    if (!start.isAfter(DateTime.now())) {
      setState(() => error = 'Choose a future date and time.');
      return;
    }
    if (requests.any(
      (r) =>
          (r['services'] as List).fold<int>(
            0,
            (sum, i) => sum + (i['duration_minutes'] as int),
          ) >
          720,
    )) {
      setState(
        () => error =
            'The combined visit for each worker must be at most 720 minutes.',
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Your Services'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${formatDate(start)} · ${formatTime(start)}'),
              Text(widget.address),
              for (final entry in widget.assignments.entries)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    '${displayService(entry.key)}\n${entry.value.name} · ${minutes(entry.key)} min · ₹${price(entry.key)}',
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                'Total labour estimate: ₹$estimate',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Text(
                'Each worker must accept their appointment. Services assigned to the same worker are performed within one combined visit. Separate workers start at the selected time. No payment is collected.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Edit'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send Requests'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final current = '$start|${notes.text}|$requests';
    if (fingerprint.isNotEmpty && fingerprint != current) {
      requestId = newBookingRequestId();
    }
    fingerprint = current;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final records = await widget.api.bookServices(
        requestId: requestId,
        start: start,
        address: widget.address,
        notes: notes.text.trim(),
        location: widget.location,
        requests: requests,
      );
      if (records.isEmpty) throw StateError('No appointments saved');
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Requests Saved'),
          content: Text(
            '${records.length} worker appointment${records.length == 1 ? '' : 's'} saved. Each appointment is waiting for worker acceptance. You can follow each status in My Jobs.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('View My Jobs'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, records.first);
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error =
              'Could not confirm the requests. A worker may be unavailable. Retry to check the saved result, or return to select workers.';
        });
      }
    }
  }

  Future<void> chooseDate() async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: day,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 89)),
    );
    if (result != null && mounted) setState(() => day = result);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Confirm Your Services')),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const CareSection('Service Address'),
                Text(widget.address),
                const SizedBox(height: 20),
                const CareSection('Selected Services & Workers'),
                for (final entry in widget.assignments.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: ServeCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayService(entry.key),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${entry.value.name} · ₹${entry.value.forService(entry.key).rate}/hour',
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            key: ValueKey('duration-${entry.key}'),
                            controller: durations[entry.key],
                            enabled: !busy,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Service duration (minutes)',
                              helperText:
                                  'Enter 15–720 minutes. Each worker’s combined visit is limited to 720 minutes.',
                            ),
                            validator: (v) {
                              final n = int.tryParse(v ?? '');
                              return n == null || n < 15 || n > 720
                                  ? 'Enter 15–720 minutes'
                                  : null;
                            },
                            onChanged: (_) => setState(() {}),
                          ),
                          Text('Labour estimate: ₹${price(entry.key)}'),
                        ],
                      ),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: busy ? null : chooseDate,
                  icon: const Icon(Icons.calendar_month),
                  label: Text(formatDate(day)),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: time,
                  enabled: !busy,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    labelText: 'Start time (24-hour HH:mm)',
                  ),
                  validator: (v) {
                    final match = RegExp(
                      r'^(\d{1,2}):(\d{2})$',
                    ).firstMatch(v?.trim() ?? '');
                    if (match == null) return 'Enter a time such as 09:30';
                    hour = int.parse(match[1]!);
                    minute = int.parse(match[2]!);
                    return hour > 23 || minute > 59
                        ? 'Enter a valid time'
                        : null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: notes,
                  enabled: !busy,
                  maxLines: 3,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'Additional details (optional)',
                  ),
                ),
                Text(
                  'Total labour estimate: ₹$estimate',
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Text(
                  'The estimate uses each service’s rate and duration. Materials require your agreement. Every assigned worker confirms their own appointment.',
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 18),
                YellowButton(
                  busy ? 'Saving…' : 'Confirm Services',
                  onPressed: busy ? null : submit,
                ),
                SizedBox(height: MediaQuery.paddingOf(context).bottom + 20),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

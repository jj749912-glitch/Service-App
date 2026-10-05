import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../tracking.dart';
import 'design.dart';

bool appointmentDayContactAllowed(Map<String, dynamic> booking, DateTime now) {
  if (!['accepted', 'completed'].contains(booking['status'])) return false;
  final start = DateTime.parse(
    booking['starts_at'] as String,
  ).toUtc().add(const Duration(hours: 5, minutes: 30));
  final today = now.toUtc().add(const Duration(hours: 5, minutes: 30));
  return start.year == today.year &&
      start.month == today.month &&
      start.day == today.day;
}

class BookingContact extends StatefulWidget {
  final Map<String, dynamic> booking;
  final Object api;
  const BookingContact({super.key, required this.booking, required this.api});
  @override
  State<BookingContact> createState() => _BookingContactState();
}

class _BookingContactState extends State<BookingContact> {
  String? phone, error;
  bool loading = false;
  Future<void> reveal() async {
    if (widget.api is! WorkerContactApi ||
        !appointmentDayContactAllowed(widget.booking, DateTime.now())) {
      return;
    }
    setState(() {
      loading = true;
      error = null;
      phone = null;
    });
    try {
      final value = await (widget.api as WorkerContactApi).workerPhone(
        widget.booking['professional_id'] as String,
      );
      if (mounted) {
        setState(() {
          phone = value;
          if (value == null) {
            error =
                'The worker has not supplied a contact number, or contact is unavailable for this booking.';
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Could not load the phone number. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void didUpdateWidget(covariant BookingContact oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!appointmentDayContactAllowed(widget.booking, DateTime.now()) ||
        oldWidget.booking['id'] != widget.booking['id']) {
      phone = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final allowed = appointmentDayContactAllowed(
      widget.booking,
      DateTime.now(),
    );
    if (!allowed) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'The worker’s phone number is available on the confirmed appointment day.',
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: loading ? null : reveal,
          icon: const Icon(Icons.phone_outlined),
          label: Text(loading ? 'Loading contact…' : 'Show Worker Phone'),
        ),
        if (phone != null)
          ListTile(
            title: SelectableText(phone!),
            trailing: IconButton(
              tooltip: 'Call Worker',
              icon: const Icon(Icons.call),
              onPressed: () async {
                bool opened;
                try {
                  opened = await launchUrl(Uri(scheme: 'tel', path: phone));
                } catch (_) {
                  opened = false;
                }
                if (!opened && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Calling is unavailable here. Copy the number to your phone.',
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        if (error != null)
          Text(error!, style: const TextStyle(color: serveError)),
      ],
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import '../app.dart' show Professional;
import '../review_dialog.dart';
import 'components.dart';
import 'customer_data.dart';
import 'design.dart';
import 'package:latlong2/latlong.dart';
import '../tracking.dart';
import 'location_map.dart';
import 'booking_contact.dart';
import 'service_booking.dart';

class MobileSchedulePage extends StatefulWidget {
  final Professional professional;
  final MobileCustomerApi api;
  final String city;
  final bool earliest;
  final String initialAddress;
  final LatLng? customerLocation;
  const MobileSchedulePage({
    super.key,
    required this.professional,
    required this.api,
    required this.city,
    this.earliest = false,
    this.initialAddress = '',
    this.customerLocation,
  });
  @override
  State<MobileSchedulePage> createState() => _MobileSchedulePageState();
}

class _MobileSchedulePageState extends State<MobileSchedulePage> {
  final form = GlobalKey<FormState>();
  final address = TextEditingController(), notes = TextEditingController();
  late DateTime selectedDay, week;
  int hour = 9, minute = 0;
  final duration = TextEditingController(text: '120');
  final time = TextEditingController(text: '09:00');
  int get minutes => int.tryParse(duration.text) ?? 0;
  num get hours => minutes / 60;
  late Professional selectedProfessional;

  bool busy = false;
  String? error;
  DateTime get start => DateTime(
    selectedDay.year,
    selectedDay.month,
    selectedDay.day,
    hour,
    minute,
  );
  @override
  void initState() {
    super.initState();
    selectedProfessional = widget.professional;
    address.text = widget.initialAddress;
    final now = DateTime.now();
    final first = widget.earliest && now.hour < 16
        ? now
        : now.add(const Duration(days: 1));
    selectedDay = DateTime(first.year, first.month, first.day);
    week = selectedDay;
    if (widget.earliest && selectedDay.day == now.day) {
      hour = now.hour + 1;
    }
    time.text = '${hour.toString().padLeft(2, '0')}:00';
  }

  @override
  void dispose() {
    time.dispose();
    duration.dispose();
    address.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> chooseDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDay,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 89)),
    );
    if (picked != null && mounted) {
      setState(() {
        selectedDay = picked;
        week = picked;
        error = null;
      });
    }
  }

  void changeWeek(int direction) {
    final now = DateTime.now();
    final candidate = week.add(Duration(days: direction * 6));
    final today = DateTime(now.year, now.month, now.day);
    if (candidate.isBefore(today) ||
        candidate.isAfter(today.add(const Duration(days: 83)))) {
      return;
    }
    setState(() => week = candidate);
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    if (!start.isAfter(DateTime.now())) {
      setState(() => error = 'Choose a future date and time.');
      return;
    }
    if (!selectedProfessional.verified) {
      setState(() => error = 'This professional is awaiting approval.');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Your Schedule'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${selectedProfessional.name} · ${displayService(selectedProfessional.service)}',
            ),
            const SizedBox(height: 10),
            Text(
              '${formatDate(start)}\n${formatTime(start)} · $minutes minutes',
            ),
            const SizedBox(height: 10),
            Text(address.text.trim()),
            const SizedBox(height: 10),
            Text(
              'Labour estimate: ₹${(selectedProfessional.rate * minutes / 60).ceil()}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'No payment is collected. Your request needs professional acceptance.',
              style: TextStyle(fontSize: 11, color: serveMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Edit'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final record = await widget.api.book(
        selectedProfessional,
        start,
        hours,
        address.text,
        notes.text,
        latitude: widget.customerLocation?.latitude,
        longitude: widget.customerLocation?.longitude,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(
            Icons.check_circle,
            color: Color(0xFF04A25B),
            size: 48,
          ),
          title: const Text('Request Sent'),
          content: Text(
            'Your request to ${record['professional_name']} has been saved.\n\nStatus: ${bookingStatus(record)}\nLabour estimate: ₹${record['total']}\n\nThe professional must accept your request.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('View My Jobs'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, record);
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error =
              'The request was not saved. This slot may be unavailable or the worker’s approval may have changed. Please retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = selectedProfessional;
    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return Scaffold(
      body: SingleChildScrollView(
        child: SolarBackdrop(
          height: 260,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MobileHeader(
                city: widget.city,
                onNotifications: () =>
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Booking updates are available in My Jobs.',
                        ),
                      ),
                    ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 5, 18, 20),
                child: Column(
                  children: [
                    PageHeading(
                      'Schedule Service',
                      subtitle:
                          'Book your solar care service in a few simple steps.',
                      onBack: busy ? null : () => Navigator.pop(context),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: List.generate(
                        4,
                        (i) => Expanded(
                          child: Column(
                            children: [
                              Container(
                                width: 23,
                                height: 23,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: i == 3
                                      ? serveYellow
                                      : Colors.white.withValues(alpha: .15),
                                  border: Border.all(color: Colors.white),
                                ),
                                child: Center(
                                  child: Text(
                                    '${i + 1}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: i == 3 ? serveNavy : Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                ['Location', 'Service', 'Worker', 'Confirm'][i],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: serveBackground,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                ),
                child: Form(
                  key: form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const CareSection('Selected Service'),
                      if (p.offerings.length > 1)
                        DropdownButtonFormField<String>(
                          initialValue: p.service,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Service to book',
                          ),
                          items: p.offerings
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s.service,
                                  child: Text(
                                    '${displayService(s.service)} · ₹${s.rate}/hr',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: busy
                              ? null
                              : (s) => setState(
                                  () => selectedProfessional = p.forService(s!),
                                ),
                        ),
                      const SizedBox(height: 12),

                      ServeCard(
                        child: Row(
                          children: [
                            ServiceArt(p.service, size: 60),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayService(p.service),
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${p.name}\n₹${p.rate} per hour',
                                    style: const TextStyle(
                                      color: serveMuted,
                                      fontSize: 11,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => Navigator.pop(context),
                              child: const Text(
                                'Change',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Select Date',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: busy ? null : () => changeWeek(-1),
                            tooltip: 'Previous dates',
                            icon: const Icon(
                              Icons.chevron_left,
                              color: serveBlue,
                            ),
                          ),
                          TextButton(
                            onPressed: busy ? null : chooseDate,
                            child: Text(
                              '${monthNames[week.month - 1]} ${week.year}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: serveNavy,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: busy ? null : () => changeWeek(1),
                            tooltip: 'Next dates',
                            icon: const Icon(
                              Icons.chevron_right,
                              color: serveBlue,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: 64,
                        child: Row(
                          children: List.generate(6, (i) {
                            final day = week.add(Duration(days: i));
                            final selected = day == selectedDay;
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                child: InkWell(
                                  onTap: busy
                                      ? null
                                      : () => setState(() {
                                          selectedDay = day;
                                          error = null;
                                        }),
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? serveBlue
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x08164E80),
                                          blurRadius: 8,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          [
                                            'Mon',
                                            'Tue',
                                            'Wed',
                                            'Thu',
                                            'Fri',
                                            'Sat',
                                            'Sun',
                                          ][day.weekday - 1],
                                          style: TextStyle(
                                            color: selected
                                                ? Colors.white
                                                : serveNavy,
                                            fontSize: 10,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          '${day.day}',
                                          style: TextStyle(
                                            color: selected
                                                ? Colors.white
                                                : serveNavy,
                                            fontSize: 17,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (selected)
                                          Container(
                                            width: 4,
                                            height: 4,
                                            decoration: const BoxDecoration(
                                              color: serveYellow,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const CareSection('Visit Time & Duration'),
                      TextFormField(
                        controller: time,
                        enabled: !busy,
                        keyboardType: TextInputType.datetime,
                        decoration: const InputDecoration(
                          labelText: 'Start time (24-hour HH:mm)',
                          hintText: '09:30',
                        ),
                        validator: (v) {
                          final match = RegExp(
                            r'^(\d{1,2}):(\d{2})$',
                          ).firstMatch(v?.trim() ?? '');
                          if (match == null) {
                            return 'Enter a time such as 09:30';
                          }
                          final h = int.parse(match[1]!);
                          final m = int.parse(match[2]!);
                          if (h > 23 || m > 59) return 'Enter a valid time';
                          hour = h;
                          minute = m;
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 13),
                      TextFormField(
                        controller: duration,
                        enabled: !busy,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Visit duration (minutes)',
                          helperText:
                              'Enter 15–720 minutes. Price is calculated per minute and rounded up to ₹1.',
                        ),
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          return n == null || n < 15 || n > 720
                              ? 'Enter 15–720 minutes'
                              : null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 19),
                      const CareSection('Preferred Worker'),
                      ServeCard(
                        child: Row(
                          children: [
                            ProfessionalAvatar(p.name, size: 58),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  RatingLine(p),
                                  Text(
                                    '${p.years} years experience${p.verified ? ' · Verified' : ''}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: serveMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.radio_button_checked,
                              color: serveBlue,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 19),
                      const CareSection('Service Address'),
                      TextFormField(
                        controller: address,
                        enabled: !busy,
                        maxLength: 1000,
                        maxLines: 2,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.location_on,
                            color: serveBlue,
                          ),
                          hintText: 'Full address in ${p.city}',
                          labelText: 'Service address',
                        ),
                        validator: (v) => (v?.trim().length ?? 0) < 10
                            ? 'Enter a full address (at least 10 characters).'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      const CareSection('Additional Details (Optional)'),
                      TextFormField(
                        controller: notes,
                        enabled: !busy,
                        maxLength: 2000,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(
                            Icons.description_outlined,
                            color: serveBlue,
                          ),
                          hintText:
                              'Panel count, roof type or special instructions',
                        ),
                      ),
                      const SizedBox(height: 10),
                      ServeCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Estimated Price',
                                    style: TextStyle(fontSize: 10),
                                  ),
                                  Text(
                                    '₹${(p.rate * minutes / 60).ceil()}',
                                    style: const TextStyle(
                                      fontSize: 27,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '₹${p.rate}/hr · labour',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: serveMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 45,
                              color: const Color(0xFFD5E2F1),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Estimated Visit Duration',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: serveMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '$minutes minutes',
                                    style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      YellowButton(
                        busy ? 'Sending Request…' : 'Confirm Schedule',
                        onPressed: busy ? null : submit,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'No payment collected. Requests need professional acceptance.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: serveMuted, fontSize: 9),
                      ),
                      SizedBox(
                        height: MediaQuery.paddingOf(context).bottom + 10,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MobileBookingDetails extends StatefulWidget {
  final Map<String, dynamic> booking;
  final MobileCustomerApi api;
  final String city;
  const MobileBookingDetails({
    super.key,
    required this.booking,
    required this.api,
    required this.city,
  });
  @override
  State<MobileBookingDetails> createState() => _MobileBookingDetailsState();
}

class _MobileBookingDetailsState extends State<MobileBookingDetails> {
  bool busy = false;
  String? error;
  late Map<String, dynamic> booking;
  Timer? refresh;
  bool refreshing = false;
  @override
  void initState() {
    super.initState();
    booking = Map.of(widget.booking);
    reload();
    refresh = Timer.periodic(const Duration(seconds: 15), (_) => reload());
  }

  @override
  void dispose() {
    refresh?.cancel();
    super.dispose();
  }

  Future<void> reload() async {
    if (refreshing) return;
    refreshing = true;
    try {
      final snapshot = await widget.api.load();
      final rows = snapshot.bookings.where((b) => b['id'] == booking['id']);
      if (mounted && rows.isNotEmpty) {
        setState(() {
          booking = Map.of(rows.first);
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not refresh this booking. Please retry.');
      }
    } finally {
      refreshing = false;
    }
  }

  Future<void> cancel() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel This Request?'),
        content: const Text('This will cancel your pending service request.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Request'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Request'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() => busy = true);
    try {
      await widget.api.cancel(booking['id'] as String);
      await reload();
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error =
              'Could not cancel. The request may already have been accepted.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SingleChildScrollView(
      child: SolarBackdrop(
        height: 225,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MobileHeader(
              city: widget.city,
              onNotifications: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Booking status: ${bookingStatus(booking)}'),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 3, 18, 20),
              child: PageHeading(
                'Booking Details',
                subtitle: bookingStatus(booking),
                onBack: () => Navigator.pop(context),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ServeCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ServiceArt(booking['service'] as String, size: 80),
                    const SizedBox(height: 12),
                    Text(
                      bookingServicesLabel(booking),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 15),
                    BookingServiceLines(booking),
                    ListTile(
                      leading: const Icon(
                        Icons.person_outline,
                        color: serveBlue,
                      ),
                      title: Text(booking['professional_name'] as String),
                      subtitle: const Text('Professional'),
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.calendar_month,
                        color: serveBlue,
                      ),
                      title: Text(
                        formatDate(
                          DateTime.parse(
                            booking['starts_at'] as String,
                          ).toLocal(),
                        ),
                      ),
                      subtitle: Text(
                        '${formatTime(DateTime.parse(booking['starts_at'] as String).toLocal())} – ${formatTime(DateTime.parse(booking['ends_at'] as String).toLocal())}',
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.location_on, color: serveBlue),
                      title: Text(booking['address'] as String),
                    ),
                    if ((booking['notes'] as String? ?? '').isNotEmpty)
                      ListTile(
                        leading: const Icon(Icons.notes, color: serveBlue),
                        title: Text(booking['notes'] as String),
                      ),
                    const Divider(),
                    Text(
                      '₹${booking['total']}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 29,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Text(
                      'Hourly labour estimate · No online payment collected',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: serveMuted),
                    ),
                    const SizedBox(height: 18),
                    BookingContact(booking: booking, api: widget.api),
                    OutlinedButton.icon(
                      onPressed: busy ? null : reload,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh Status'),
                    ),
                    if (booking['status'] == 'requested')
                      OutlinedButton(
                        onPressed: busy ? null : cancel,
                        child: Text(busy ? 'Cancelling…' : 'Cancel Request'),
                      ),
                    if (booking['status'] == 'completed')
                      FilledButton.icon(
                        onPressed: () async {
                          final saved = await showDialog<bool>(
                            context: context,
                            builder: (_) => ReviewDialog(booking: booking),
                          );
                          if (saved == true && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Your review has been published. Thank you.',
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.star_outline),
                        label: const Text('Write a Review'),
                      ),
                    if (error != null)
                      Text(error!, style: const TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class MobileTrackingPage extends StatefulWidget {
  final Map<String, dynamic> booking;
  final MobileCustomerApi api;
  final String city;
  final bool mapsEnabled;
  const MobileTrackingPage({
    super.key,
    required this.booking,
    required this.api,
    required this.city,
    this.mapsEnabled = true,
  });
  @override
  State<MobileTrackingPage> createState() => _MobileTrackingPageState();
}

class _MobileTrackingPageState extends State<MobileTrackingPage> {
  late Map<String, dynamic> booking;
  Map<String, dynamic>? location;
  Timer? timer;
  bool refreshing = false;
  String? error;
  @override
  void initState() {
    super.initState();
    booking = Map.of(widget.booking);
    reload();
    timer = Timer.periodic(const Duration(seconds: 5), (_) => reload());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> reload() async {
    if (refreshing) return;
    refreshing = true;
    try {
      final snapshot = await widget.api.load();
      final updated = snapshot.bookings
          .where((b) => b['id'] == booking['id'])
          .firstOrNull;
      if (updated == null) throw StateError('Booking no longer available');
      Map<String, dynamic>? point;
      if (trackingWindowOpen(updated, DateTime.now()) &&
          widget.api is BookingUpdatesApi) {
        point = await (widget.api as BookingUpdatesApi).workerLocation(
          booking['id'] as String,
        );
      }
      if (mounted) {
        setState(() {
          booking = Map.of(updated);
          location = point;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          location = null;
          error =
              'Could not refresh your booking or location. Check your connection and retry.';
        });
      }
    } finally {
      refreshing = false;
    }
  }

  bool get live {
    if (location == null || !trackingWindowOpen(booking, DateTime.now())) {
      return false;
    }
    final timestamp = DateTime.tryParse(
      location!['updated_at'] as String? ?? '',
    );
    return timestamp != null &&
        DateTime.now().difference(timestamp) < const Duration(minutes: 2);
  }

  @override
  Widget build(BuildContext context) {
    final worker = live
        ? LatLng(
            (location!['latitude'] as num).toDouble(),
            (location!['longitude'] as num).toDouble(),
          )
        : null;
    final customer =
        booking['customer_latitude'] == null ||
            booking['customer_longitude'] == null
        ? null
        : LatLng(
            (booking['customer_latitude'] as num).toDouble(),
            (booking['customer_longitude'] as num).toDouble(),
          );
    return Scaffold(
      appBar: AppBar(title: const Text('Live Tracking')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ServeCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bookingStatus(booking),
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    live
                        ? 'Worker location updated at ${formatTime(DateTime.parse(location!['updated_at'] as String).toLocal())}.'
                        : trackingAvailability(booking, DateTime.now()),
                  ),
                  if (live)
                    Text(
                      'Location accuracy: about ${(location!['accuracy'] as num).round()} m',
                      style: const TextStyle(color: serveMuted, fontSize: 11),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 380,
              child: LocationMap(
                center: worker ?? customer ?? cityCenter(widget.city),
                enabled: widget.mapsEnabled,
                pins: [
                  if (customer != null)
                    LocationPin('customer', 'Your Location', customer),
                  if (worker != null)
                    LocationPin(
                      'worker',
                      booking['professional_name'] as String,
                      worker,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ServeCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking['professional_name'] as String,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(bookingServicesLabel(booking)),
                  BookingContact(booking: booking, api: widget.api),
                  Text(
                    'Progress: ${booking['journey_status'] ?? 'not_started'}',
                  ),
                  for (final entry in [
                    ('Request Sent', 'created_at'),
                    ('Journey Started', 'journey_started_at'),
                    ('Arrived', 'arrived_at'),
                    ('Work Started', 'work_started_at'),
                    ('Completed', 'work_completed_at'),
                  ])
                    if (booking[entry.$2] != null)
                      ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.check_circle_outline,
                          color: Colors.green,
                        ),
                        title: Text(entry.$1),
                        subtitle: Text(
                          formatTime(
                            DateTime.parse(
                              booking[entry.$2] as String,
                            ).toLocal(),
                          ),
                        ),
                      ),
                  Text(booking['address'] as String),
                  const SizedBox(height: 10),
                  Text(
                    '${formatDate(DateTime.parse(booking['starts_at'] as String).toLocal())} · ${formatTime(DateTime.parse(booking['starts_at'] as String).toLocal())}',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Tracking is private to this confirmed visit. It stops after cancellation, completion or the visit end time.',
                  ),
                ],
              ),
            ),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 15),
            OutlinedButton.icon(
              onPressed: reload,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Status'),
            ),
          ],
        ),
      ),
    );
  }
}

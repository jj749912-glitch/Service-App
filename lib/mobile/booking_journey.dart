import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../app.dart' show Professional;
import '../locations.dart';
import '../service_offering.dart';
import 'booking_pages.dart';
import 'components.dart';
import 'customer_data.dart';
import 'design.dart';
import 'location_map.dart';
import '../tracking.dart';
import 'service_booking.dart';

class BookingJourney extends StatefulWidget {
  final MobileCustomerApi api;
  final String city, initialService;
  final bool mapsEnabled;
  const BookingJourney({
    super.key,
    required this.api,
    required this.city,
    this.initialService = 'Solar cleaning',
    this.mapsEnabled = true,
  });
  @override
  State<BookingJourney> createState() => _BookingJourneyState();
}

class _BookingJourneyState extends State<BookingJourney> {
  final form = GlobalKey<FormState>();
  final address = TextEditingController();
  late String city, service;
  final selectedServices = <String>{};
  final assignments = <String, Professional>{};
  bool separateWorkers = false;
  bool get ready => separateWorkers
      ? selectedServices.every(assignments.containsKey)
      : chosen != null;
  void selectWorker(Professional p) => setState(() {
    if (separateWorkers) {
      assignments[service] = p;
    } else {
      chosen = p;
    }
  });
  String sort = 'Nearest';
  LatLng? location;
  int step = 0;
  bool busy = false;
  String? error;
  List<Professional> catalog = [];
  List<Map<String, dynamic>> availability = [];
  Professional? chosen;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    city = widget.city;
    service = offeredServices.contains(widget.initialService)
        ? widget.initialService
        : 'Solar cleaning';
    selectedServices.add(service);
    timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (step == 2 && !busy) loadWorkers();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    address.dispose();
    super.dispose();
  }

  Future<void> useLocation() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError(
          'Turn on location services or select your location on the map.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError(
          'Location access was denied. Select your location on the map instead.',
        );
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (mounted) setState(() => location = LatLng(p.latitude, p.longitude));
    } on StateError catch (e) {
      if (mounted) setState(() => error = e.message.toString());
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              error = 'Could not get your location. Tap the map to select it.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> loadWorkers() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final snapshot = await widget.api.load();
      final points = widget.api is NearbyWorkersApi
          ? await (widget.api as NearbyWorkersApi).availableWorkers()
          : <Map<String, dynamic>>[];
      if (mounted) {
        setState(() {
          catalog = snapshot.professionals;
          availability = points;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not load nearby workers. Please retry.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  List<({Professional worker, LatLng point, double km})> get workers {
    if (location == null) return [];
    final result = <({Professional worker, LatLng point, double km})>[];
    for (final point in availability) {
      final worker = catalog
          .where(
            (p) =>
                p.id == point['professional_id'] &&
                p.verified &&
                p.city == city &&
                (separateWorkers
                    ? p.offers(service)
                    : selectedServices.every(p.offers)),
          )
          .firstOrNull;
      if (worker == null) continue;
      final updated = DateTime.tryParse(point['updated_at'] as String? ?? '');
      if (updated == null ||
          DateTime.now().difference(updated) > const Duration(minutes: 2)) {
        continue;
      }
      final geo = LatLng(
        (point['latitude'] as num).toDouble(),
        (point['longitude'] as num).toDouble(),
      );
      final km = const Distance().as(LengthUnit.Kilometer, location!, geo);
      if (km <= 50) {
        result.add((worker: worker.forService(service), point: geo, km: km));
      }
    }
    result.sort(
      (a, b) => switch (sort) {
        'Lowest Price' => a.worker.rate.compareTo(b.worker.rate),
        'Top Rated' => b.worker.rating.compareTo(a.worker.rating),
        _ => a.km.compareTo(b.km),
      },
    );
    return result;
  }

  Future<void> next() async {
    if (step == 0) {
      if (!form.currentState!.validate()) return;
      if (location == null) {
        setState(
          () => error = 'Select your location using GPS or tap the map.',
        );
        return;
      }
      setState(() {
        step = 1;
        error = null;
      });
    } else if (step == 1) {
      if (selectedServices.isEmpty) {
        setState(() => error = 'Select at least one service.');
        return;
      }
      setState(() {
        step = 2;
        chosen = null;
        assignments.clear();
        service = selectedServices.first;
      });
      await loadWorkers();
    } else if (ready) {
      if (selectedServices.length > 1) {
        final selected = separateWorkers
            ? Map<String, Professional>.from(assignments)
            : {for (final s in selectedServices) s: chosen!};
        for (final entry in selected.entries) {
          if (!entry.value.offers(entry.key) ||
              !availability.any(
                (p) =>
                    p['professional_id'] == entry.value.id &&
                    DateTime.now().difference(
                          DateTime.tryParse(p['updated_at'] as String? ?? '') ??
                              DateTime(2000),
                        ) <
                        const Duration(minutes: 2),
              )) {
            setState(
              () => error =
                  'A selected worker is no longer available. Refresh and select workers again.',
            );
            return;
          }
        }
        if (widget.api is! MultiServiceBookingApi) {
          setState(
            () => error =
                'Multi-service booking is unavailable. Please update the app.',
          );
          return;
        }
        final record = await Navigator.of(context).push<Map<String, dynamic>>(
          MaterialPageRoute(
            builder: (_) => MultiServiceSchedulePage(
              api: widget.api as MultiServiceBookingApi,
              assignments: selected,
              address: address.text.trim(),
              location: location!,
            ),
          ),
        );
        if (record != null && mounted) Navigator.pop(context, record);
        return;
      }
      final selectedWorker = separateWorkers ? assignments[service] : chosen;
      final available = workers
          .where((w) => w.worker.id == selectedWorker!.id)
          .firstOrNull;
      if (available == null) {
        setState(
          () => error =
              'This worker is no longer available. Choose another worker.',
        );
        return;
      }
      final record = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
          builder: (_) => MobileSchedulePage(
            professional: available.worker,
            api: widget.api,
            city: city,
            initialAddress: address.text.trim(),
            customerLocation: location,
          ),
        ),
      );
      if (record != null && mounted) Navigator.pop(context, record);
    }
  }

  Widget stepContent() {
    if (step == 0) {
      final fields = Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CareSection('Select Your Location'),
            const Text(
              'Enter your address and choose the exact service location.',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: city,
              decoration: const InputDecoration(labelText: 'Service city'),
              items: serviceCities
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (c) => setState(() {
                city = c!;
                location = null;
              }),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: address,
              maxLength: 1000,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Full service address',
                hintText: 'House name / number, street, landmark and PIN code',
              ),
              validator: (v) => (v?.trim().length ?? 0) < 10
                  ? 'Enter a complete service address'
                  : null,
            ),
            OutlinedButton.icon(
              onPressed: busy ? null : useLocation,
              icon: const Icon(Icons.my_location),
              label: const Text('Use Current Location'),
            ),
            const SizedBox(height: 10),
            Text(
              location == null
                  ? 'Tap the map to select your location.'
                  : 'Location selected · ${location!.latitude.toStringAsFixed(4)}, ${location!.longitude.toStringAsFixed(4)}',
              style: const TextStyle(color: serveMuted, fontSize: 12),
            ),
          ],
        ),
      );
      final map = SizedBox(
        height: 350,
        child: LocationMap(
          center: location ?? cityCenter(city),
          enabled: widget.mapsEnabled,
          onPick: (p) => setState(() => location = p),
          pins: location == null
              ? []
              : [LocationPin('customer', 'Your Location', location!)],
        ),
      );
      return LayoutBuilder(
        builder: (ctx, c) => c.maxWidth > 700
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: fields),
                  const SizedBox(width: 25),
                  Expanded(child: map),
                ],
              )
            : Column(children: [fields, const SizedBox(height: 16), map]),
      );
    }
    if (step == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CareSection('Select Your Services'),
          const Text('Choose one or more services for this visit.'),
          Text('Service address: ${address.text}'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: offeredServices
                .map(
                  (s) => SizedBox(
                    width: 145,
                    child: InkWell(
                      onTap: () => setState(() {
                        if (!selectedServices.add(s)) {
                          selectedServices.remove(s);
                        }
                        error = null;
                      }),
                      child: ServeCard(
                        color: selectedServices.contains(s)
                            ? const Color(0xFFE0F6EA)
                            : Colors.white,
                        child: Column(
                          children: [
                            ServiceArt(s, size: 65),
                            const SizedBox(height: 8),
                            Text(
                              displayService(s),
                              textAlign: TextAlign.center,
                            ),
                            if (selectedServices.contains(s))
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          const Text(
            'Prices are set by each professional. Choose your worker next.',
          ),
        ],
      );
    }
    final nearby = workers;
    final map = SizedBox(
      height: 390,
      child: LocationMap(
        center: location!,
        enabled: widget.mapsEnabled,
        pins: [
          LocationPin('customer', 'Your Location', location!),
          ...nearby.map(
            (w) => LocationPin(
              w.worker.id,
              w.worker.name,
              w.point,
              onTap: () => selectWorker(w.worker),
            ),
          ),
        ],
      ),
    );
    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CareSection('Nearby Professionals'),
        Text(
          '${separateWorkers ? displayService(service) : selectedServices.map(displayService).join(' + ')} · within 50 km · approximate shared locations',
          style: const TextStyle(color: serveMuted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        if (nearby.isEmpty && !busy)
          const EmptyCare(
            icon: Icons.person_search,
            title: 'No available workers nearby',
            message:
                'Approved workers appear here when they enable availability in their app. Try another service or check again later.',
          ),
        for (final w in nearby)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ServeCard(
              color:
                  (separateWorkers ? assignments[service]?.id : chosen?.id) ==
                      w.worker.id
                  ? const Color(0xFFE9F6FF)
                  : Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ProfessionalAvatar(w.worker.name, size: 50),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              w.worker.name,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            RatingLine(w.worker),
                            Text(
                              '${w.km.toStringAsFixed(1)} km · ₹${w.worker.rate}/hour',
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        (separateWorkers
                                    ? assignments[service]?.id
                                    : chosen?.id) ==
                                w.worker.id
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: serveBlue,
                      ),
                    ],
                  ),
                  Text(
                    w.worker.bio,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final option in w.worker.offerings)
                        Chip(
                          label: Text(
                            '${displayService(option.service)} · ₹${option.rate}/hr',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                  Wrap(
                    spacing: 12,
                    children: [
                      TextButton(
                        onPressed: () => profile(w.worker),
                        child: const Text('View Profile & Reviews'),
                      ),
                      FilledButton(
                        onPressed: () => selectWorker(w.worker),
                        child: const Text('Select Worker'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
    return Column(
      children: [
        if (selectedServices.length > 1) ...[
          Wrap(
            spacing: 10,
            children: [
              ChoiceChip(
                label: const Text('One worker for all services'),
                selected: !separateWorkers,
                onSelected: (_) => setState(() {
                  separateWorkers = false;
                  chosen = null;
                  assignments.clear();
                }),
              ),
              ChoiceChip(
                label: const Text('Choose a worker for each service'),
                selected: separateWorkers,
                onSelected: (_) => setState(() {
                  separateWorkers = true;
                  chosen = null;
                  assignments.clear();
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            separateWorkers
                ? 'Select a worker for every service below.'
                : 'Only workers who offer every selected service are shown.',
          ),
          if (separateWorkers)
            Wrap(
              spacing: 8,
              children: [
                for (final s in selectedServices)
                  ChoiceChip(
                    label: Text(
                      '${displayService(s)}${assignments[s] == null ? '' : ' ✓ ${assignments[s]!.name}'}',
                    ),
                    selected: service == s,
                    onSelected: (_) => setState(() => service = s),
                  ),
              ],
            ),
          const SizedBox(height: 15),
        ],
        Wrap(
          spacing: 10,
          children: ['Nearest', 'Top Rated', 'Lowest Price']
              .map(
                (s) => ChoiceChip(
                  selected: sort == s,
                  label: Text(s),
                  onSelected: (_) => setState(() => sort = s),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 15),
        LayoutBuilder(
          builder: (ctx, c) => c.maxWidth > 700
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: map),
                    const SizedBox(width: 20),
                    Expanded(flex: 5, child: list),
                  ],
                )
              : Column(children: [map, const SizedBox(height: 18), list]),
        ),
      ],
    );
  }

  Future<void> profile(Professional p) async {
    List<Map<String, dynamic>> reviews;
    try {
      reviews = await widget.api.reviews(p.id);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not load reviews. Please retry.');
      }
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(p.name),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RatingLine(p),
                Text(p.qualification),
                Text('${p.years} years experience · ₹${p.rate}/hour'),
                Text(p.bio),
                for (final option in p.offerings)
                  Text(
                    '${displayService(option.service)} · ₹${option.rate}/hr · ${option.years} years experience\n${option.details}',
                  ),
                const SizedBox(height: 15),
                const Text(
                  'Reviews',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                if (reviews.isEmpty) const Text('No reviews yet.'),
                for (final r in reviews)
                  ListTile(
                    title: Text('${r['rating']} ★ · ${r['author_name']}'),
                    subtitle: Text(r['body'] as String),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              selectWorker(p);
              Navigator.pop(ctx);
            },
            child: const Text('Select Worker'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const ServeBrand(size: 22)),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Book a Service',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 18),
              Row(
                children: List.generate(
                  4,
                  (i) => Expanded(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 15,
                          backgroundColor: i <= step
                              ? serveBlue
                              : const Color(0xFFD8E7F0),
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: i <= step ? Colors.white : serveMuted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          ['Location', 'Service', 'Worker', 'Confirm'][i],
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 25),
              if (busy) const LinearProgressIndicator(),
              stepContent(),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 22),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (step > 0)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() {
                              step--;
                              error = null;
                            }),
                      child: const Text('Back'),
                    ),
                  if (step == 2)
                    TextButton(
                      onPressed: busy ? null : loadWorkers,
                      child: const Text('Refresh Workers'),
                    ),
                  FilledButton(
                    onPressed: busy || (step == 2 && !ready) ? null : next,
                    child: Text(
                      [
                        'Confirm Location',
                        'Continue to Workers',
                        'Continue to Confirm',
                      ][step],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'tracking.dart';

/// Explicit, foreground-only sharing. GPS is never requested outside the window.
class WorkerTrackingControl extends StatefulWidget {
  final Map<String, dynamic>? booking;
  final String? professionalId;
  const WorkerTrackingControl({super.key, required this.booking})
    : professionalId = null;
  const WorkerTrackingControl.availability({
    super.key,
    required this.professionalId,
  }) : booking = null;
  @override
  State<WorkerTrackingControl> createState() => _WorkerTrackingControlState();
}

class _WorkerTrackingControlState extends State<WorkerTrackingControl>
    with WidgetsBindingObserver {
  final client = Supabase.instance.client;
  bool enabled = false, updating = false, foreground = true;
  Timer? timer;
  String? message;
  bool get discovery => widget.professionalId != null;
  String get id => widget.professionalId ?? widget.booking!['id'] as String;
  String get table => discovery ? 'worker_availability' : 'worker_locations';
  String get idColumn => discovery ? 'professional_id' : 'booking_id';
  bool get window =>
      discovery || trackingWindowOpen(widget.booking!, DateTime.now());
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    timer = Timer.periodic(const Duration(seconds: 10), (_) => update());
  }

  Future<void> clear() async {
    try {
      await client.from(table).delete().eq(idColumn, id);
    } catch (_) {
      /* Old points expire on the server after two minutes. */
    }
  }

  @override
  void dispose() {
    enabled = false;
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(clear());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (!foreground) {
      unawaited(clear());
    } else {
      update();
    }
  }

  Future<void> toggle(bool value) async {
    setState(() {
      enabled = value;
      message = null;
    });
    if (!value) {
      await clear();
      return;
    }
    await update();
  }

  Future<void> update() async {
    if (!mounted || !enabled || updating || !foreground) return;
    if (!window) {
      if (mounted) {
        setState(
          () => message = trackingAvailability(widget.booking!, DateTime.now()),
        );
      }
      return;
    }
    updating = true;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('Turn on location services to share your location.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError(
          'Location permission is required. Enable it in your device or browser settings.',
        );
      }
      if (!mounted || !enabled || !foreground || !window) {
        return;
      }
      final point = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted || !enabled || !foreground || !window) {
        return;
      }
      await client.from(table).upsert({
        idColumn: id,
        'latitude': point.latitude,
        'longitude': point.longitude,
        if (!discovery) 'accuracy': point.accuracy,
      });
      if (!mounted || !enabled || !foreground) {
        await clear();
        return;
      }
      setState(
        () => message = discovery
            ? 'Online: nearby customers can see your approximate location.'
            : 'Sharing your current location with this customer.',
      );
    } on StateError catch (e) {
      if (mounted) {
        setState(() {
          message = e.message.toString();
          enabled = false;
        });
      }
      await clear();
    } catch (_) {
      if (mounted) {
        setState(
          () => message =
              'Location update failed. Check your connection and location permission. Retrying while sharing is on.',
        );
      }
    } finally {
      updating = false;
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          discovery
              ? 'Online for nearby bookings'
              : 'Share location for this visit',
        ),
        value: enabled,
        onChanged: toggle,
        subtitle: Text(
          discovery
              ? 'Share an approximate location while this app is open. Turn off to stop appearing as available.'
              : 'Starts 20 minutes before the visit. Keep the worker app open. Sharing stops when the visit ends or you turn it off.',
        ),
      ),
      if (message != null) Text(message!, style: const TextStyle(fontSize: 12)),
    ],
  );
}

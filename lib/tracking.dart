/// Both ends use the same window; the database independently enforces it.
bool trackingWindowOpen(Map<String, dynamic> booking, DateTime now) =>
    booking['status'] == 'accepted' &&
    !now.isBefore(
      DateTime.parse(
        booking['starts_at'] as String,
      ).subtract(const Duration(minutes: 20)),
    ) &&
    now.isBefore(DateTime.parse(booking['ends_at'] as String));

String trackingAvailability(Map<String, dynamic> booking, DateTime now) {
  if (booking['status'] != 'accepted') {
    return 'Tracking is available only for a confirmed appointment.';
  }
  if (now.isBefore(
    DateTime.parse(
      booking['starts_at'] as String,
    ).subtract(const Duration(minutes: 20)),
  )) {
    return 'Tracking opens 20 minutes before your appointment.';
  }
  if (!now.isBefore(DateTime.parse(booking['ends_at'] as String))) {
    return 'The location-sharing window has ended.';
  }
  return 'Waiting for the worker to share their location. Keep this page open for updates.';
}

abstract interface class BookingUpdatesApi {
  Stream<void> get bookingChanges;
  Future<void> readNotifications(List<String> ids);
  Future<Map<String, dynamic>?> workerLocation(String bookingId);
}

abstract interface class NearbyWorkersApi {
  Future<List<Map<String, dynamic>>> availableWorkers();
}

abstract interface class WorkerUpdatesApi {
  Stream<void> get jobChanges;
}

abstract interface class WorkerContactApi {
  Future<String?> workerPhone(String professionalId);
}

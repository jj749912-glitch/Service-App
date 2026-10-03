import 'package:solarcare/bootstrap.dart';
import 'package:solarcare/worker_app.dart';

Future<void> main() =>
    launchSolarCare(const SolarCareWorkerApp(), worker: true);

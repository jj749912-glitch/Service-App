import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'backend_config.dart';

// Worker sessions and PKCE verifiers remain separate from customer sessions,
// even when both web apps share one Netlify hostname.
class WorkerPkceStorage extends GotrueAsyncStorage {
  final base = SharedPreferencesGotrueAsyncStorage();
  @override
  Future<String?> getItem({required String key}) =>
      base.getItem(key: 'solarcare_worker_$key');
  @override
  Future<void> setItem({required String key, required String value}) =>
      base.setItem(key: 'solarcare_worker_$key', value: value);
  @override
  Future<void> removeItem({required String key}) =>
      base.removeItem(key: 'solarcare_worker_$key');
}

Future<void> launchSolarCare(Widget app, {bool worker = false}) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (!connected) throw StateError('Missing public connection settings');
    await Supabase.initialize(
      url: backendUrl,
      publishableKey: backendKey,
      authOptions: worker
          ? FlutterAuthClientOptions(
              localStorage: SharedPreferencesLocalStorage(
                persistSessionKey: 'solarcare_worker_session',
              ),
              pkceAsyncStorage: WorkerPkceStorage(),
            )
          : const FlutterAuthClientOptions(),
    );
    runApp(app);
  } catch (_) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 48),
                  const SizedBox(height: 20),
                  const Text(
                    'Could not start the app. Please try again.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => launchSolarCare(app, worker: worker),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

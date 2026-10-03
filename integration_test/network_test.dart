import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:solarcare/backend_config.dart';

// Read-only connectivity checks. No accounts, passwords or database writes.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final url in ['https://example.com', '$backendUrl/auth/v1/health']) {
    testWidgets('Native HTTPS reaches $url', (t) async {
      await t.runAsync(() async {
        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 15);
        try {
          final request = await client
              .getUrl(Uri.parse(url))
              .timeout(const Duration(seconds: 20));
          request.headers.set('apikey', backendKey);
          final response = await request.close().timeout(
            const Duration(seconds: 20),
          );
          await response.drain<void>();
          expect(response.statusCode, HttpStatus.ok);
        } finally {
          client.close(force: true);
        }
      });
    });
  }
}

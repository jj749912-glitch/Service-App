import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (connected) {
    await Supabase.initialize(url: backendUrl, publishableKey: backendKey);
  }
  runApp(const SolarCareApp());
}

import 'package:flutter/material.dart';
import 'auth_gate.dart';
import 'app_theme.dart';
import 'provider_portal.dart';

class SolarCareWorkerApp extends StatelessWidget {
  final AppAuthApi? auth;
  final WidgetBuilder? workspaceBuilder;
  const SolarCareWorkerApp({super.key, this.auth, this.workspaceBuilder});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SolarCare Pro',
    debugShowCheckedModeBanner: false,
    theme: solarCareTheme(),
    home: AuthGate(
      api: auth,
      worker: true,
      signedInBuilder: workspaceBuilder ?? (_) => const ProviderPortal(),
    ),
  );
}

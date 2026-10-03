import 'package:flutter/material.dart';
import 'auth_gate.dart';
import 'mobile/design.dart';
import 'mobile/login.dart';
import 'provider_portal.dart';

class SolarCareWorkerApp extends StatelessWidget {
  final AppAuthApi? auth;
  final WidgetBuilder? workspaceBuilder;
  const SolarCareWorkerApp({super.key, this.auth, this.workspaceBuilder});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SolarServe Pro',
    debugShowCheckedModeBanner: false,
    theme: solarServeTheme(worker: true),
    scrollBehavior: const SolarServeScrollBehavior(),
    builder: (context, child) => SolarServeFrame(child: child!),
    home: AuthGate(
      api: auth,
      worker: true,
      signedOutBuilder: (api) => MobileLoginScreen(api: api, worker: true),
      signedInBuilder:
          workspaceBuilder ??
          (_) => const ProviderPortal(assetPackage: 'solarcare'),
    ),
  );
}

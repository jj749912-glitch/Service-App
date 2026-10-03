import 'package:flutter/material.dart';
import 'app.dart';
import 'bootstrap.dart';

// Isolated preview of the same SolarServe interface used by production web.
// This preview uses the same real login and backend as the mobile application.
Future<void> main() => launchSolarCare(
  const ColoredBox(
    color: Color(0xFFE5ECF2),
    child: Center(
      child: SizedBox(width: 430, child: SolarCareApp(mobile: true)),
    ),
  ),
);

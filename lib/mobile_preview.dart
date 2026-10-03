import 'package:flutter/material.dart';
import 'app.dart';
import 'bootstrap.dart';

// Local design preview only. Normal web builds keep the existing web interface.
// This preview uses the same real login and backend as the mobile application.
Future<void> main() => launchSolarCare(
  const ColoredBox(
    color: Color(0xFFE5ECF2),
    child: Center(
      child: SizedBox(width: 430, child: SolarCareApp(mobile: true)),
    ),
  ),
);

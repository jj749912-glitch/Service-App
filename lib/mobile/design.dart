import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

const serveBlue = Color(0xFF007CEA);
const serveNavy = Color(0xFF071442);
const serveMuted = Color(0xFF607396);
const serveYellow = Color(0xFFFFCF27);
const serveBackground = Color(0xFFF3F8FB);
const mobileBrand = 'SolarServe';

// Keep the supplied phone composition on wide browser windows. The local
// MediaQuery also keeps dialogs and date/time controls inside that composition.
class SolarServeFrame extends StatelessWidget {
  final Widget child;
  const SolarServeFrame({super.key, required this.child});
  @override
  Widget build(BuildContext context) =>
      kIsWeb && MediaQuery.sizeOf(context).width >= 900
      ? child
      : ColoredBox(
          color: const Color(0xFFE5ECF2),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: LayoutBuilder(
                builder: (context, constraints) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                  ),
                  child: ClipRect(child: child),
                ),
              ),
            ),
          ),
        );
}

class SolarServeScrollBehavior extends MaterialScrollBehavior {
  const SolarServeScrollBehavior();
  @override
  Set<PointerDeviceKind> get dragDevices => {
    ...super.dragDevices,
    PointerDeviceKind.mouse,
  };
}

ThemeData solarServeTheme({bool worker = false}) => ThemeData(
  useMaterial3: true,
  fontFamily: worker ? 'packages/solarcare/Poppins' : 'Poppins',
  scaffoldBackgroundColor: serveBackground,
  colorScheme: ColorScheme.fromSeed(
    seedColor: serveBlue,
    primary: serveBlue,
    secondary: serveYellow,
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: serveNavy, fontSize: 13),
    bodyLarge: TextStyle(color: serveNavy, fontSize: 15),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: serveBlue,
    foregroundColor: Colors.white,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Color(0xFFDCE8F5)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Color(0xFFDCE8F5)),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: serveBlue,
      foregroundColor: Colors.white,
      minimumSize: const Size(0, 48),
      shape: const StadiumBorder(),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: serveBlue,
      side: const BorderSide(color: serveBlue),
      minimumSize: const Size(0, 48),
      shape: const StadiumBorder(),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: serveBlue),
  ),
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
  ),
  chipTheme: ChipThemeData(
    side: BorderSide.none,
    shape: const StadiumBorder(),
    backgroundColor: Colors.white,
    selectedColor: serveBlue,
    labelStyle: TextStyle(
      fontFamily: worker ? 'packages/solarcare/Poppins' : 'Poppins',
      fontSize: 12,
    ),
  ),
);

class ServeBrand extends StatelessWidget {
  final bool dark;
  final bool worker;
  final double size;
  const ServeBrand({
    super.key,
    this.dark = false,
    this.worker = false,
    this.size = 22,
  });
  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              size: Size(size * 1.4, size * 1.4),
              painter: _SunPanelMark(),
            ),
            const SizedBox(width: 5),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Solar',
                    style: TextStyle(color: dark ? serveNavy : Colors.white),
                  ),
                  const TextSpan(
                    text: 'Serve',
                    style: TextStyle(color: serveYellow),
                  ),
                  if (worker)
                    TextSpan(
                      text: ' Pro',
                      style: TextStyle(
                        color: dark ? serveNavy : Colors.white,
                        fontSize: size * .6,
                      ),
                    ),
                ],
              ),
              style: TextStyle(
                fontSize: size,
                fontWeight: FontWeight.w700,
                letterSpacing: -.7,
              ),
            ),
          ],
        ),
        Text(
          'CLEANER PANELS  BRIGHTER TOMORROW',
          style: TextStyle(
            color: dark ? serveNavy : Colors.white,
            fontSize: size * .215,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _SunPanelMark extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * .5, size.height * .51);
    final paint = Paint()..color = serveYellow;
    canvas.drawCircle(center, size.width * .24, paint);
    paint.strokeWidth = size.width * .045;
    for (var i = 0; i < 11; i++) {
      final angle = math.pi + i * math.pi / 10;
      canvas.drawLine(
        center + Offset(math.cos(angle), math.sin(angle)) * size.width * .32,
        center + Offset(math.cos(angle), math.sin(angle)) * size.width * .43,
        paint,
      );
    }
    final panel = Path()
      ..moveTo(size.width * .13, size.height * .78)
      ..lineTo(size.width * .28, size.height * .57)
      ..lineTo(size.width * .72, size.height * .57)
      ..lineTo(size.width * .9, size.height * .78)
      ..close();
    canvas.drawPath(panel, Paint()..color = serveBlue);
    canvas.drawPath(
      panel,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = Colors.white,
    );
    for (final x in [.36, .5, .64]) {
      canvas.drawLine(
        Offset(size.width * x, size.height * .59),
        Offset(size.width * x, size.height * .76),
        Paint()
          ..color = Colors.white
          ..strokeWidth = .7,
      );
    }
    canvas.drawLine(
      Offset(size.width * .22, size.height * .67),
      Offset(size.width * .79, size.height * .67),
      Paint()
        ..color = Colors.white
        ..strokeWidth = .7,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class ServeCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? color;
  const ServeCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.color,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.white.withValues(alpha: .8)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF164E80).withValues(alpha: .055),
          blurRadius: 18,
          offset: const Offset(0, 7),
        ),
      ],
    ),
    child: child,
  );
}

class YellowButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool arrow;
  const YellowButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.arrow = true,
  });
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(100),
      gradient: const LinearGradient(
        colors: [Color(0xFFFFE44F), Color(0xFFFFBB18)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      boxShadow: [
        BoxShadow(
          color: serveYellow.withValues(alpha: .16),
          blurRadius: 12,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: serveNavy,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          if (arrow) ...[
            const SizedBox(width: 10),
            const Icon(Icons.arrow_forward, size: 20),
          ],
        ],
      ),
    ),
  );
}

class ServiceArt extends StatelessWidget {
  final String service;
  final double size;
  final String? assetPackage;
  const ServiceArt(
    this.service, {
    super.key,
    this.size = 52,
    this.assetPackage,
  });
  String get asset => switch (service) {
    'Solar cleaning' => 'solar-cleaning',
    'Solar inspection' => 'solar-maintenance',
    'Solar repair' => 'repair',
    'Electrical' => 'electrical',
    'Plumbing' => 'plumbing',
    'Home cleaning' => 'cleaning',
    _ => 'solar-maintenance',
  };
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/mobile/$asset.png',
    package: assetPackage,
    width: size,
    height: size,
    cacheWidth: (size * 3).round(),
    errorBuilder: (_, error, stack) => Icon(
      switch (service) {
        'Electrical' => Icons.bolt,
        'Plumbing' => Icons.water_drop,
        'Home cleaning' => Icons.cleaning_services,
        'Solar repair' => Icons.handyman,
        _ => Icons.solar_power,
      },
      color: service == 'Electrical' ? serveYellow : serveBlue,
      size: size * .8,
    ),
  );
}

class GlassSearch extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onFilter;
  const GlassSearch({
    super.key,
    required this.hint,
    required this.onChanged,
    required this.onFilter,
  });
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: TextField(
              onChanged: onChanged,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Colors.white, fontSize: 12),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Colors.white,
                  size: 25,
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: .25),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 15,
                  horizontal: 16,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(40),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: .5),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(40),
                  borderSide: const BorderSide(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      IconButton(
        onPressed: onFilter,
        tooltip: 'Filter services',
        icon: const Icon(Icons.tune, color: Colors.white),
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: .3),
          padding: const EdgeInsets.all(14),
          side: BorderSide(color: Colors.white.withValues(alpha: .4)),
        ),
      ),
    ],
  );
}

class EmptyCare extends StatelessWidget {
  final IconData icon;
  final String title, message;
  final Widget? action;
  const EmptyCare({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  @override
  Widget build(BuildContext context) => ServeCard(
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            color: Color(0xFFEAF5FF),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: serveBlue, size: 30),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        const SizedBox(height: 7),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: serveMuted, fontSize: 12, height: 1.6),
        ),
        if (action != null) ...[const SizedBox(height: 12), action!],
      ],
    ),
  );
}

class PageHeading extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  const PageHeading(this.title, {super.key, this.subtitle, this.onBack});
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (onBack != null)
        IconButton(
          onPressed: onBack,
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 40),
        ),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 27,
                fontWeight: FontWeight.w600,
                height: 1.25,
                letterSpacing: -.6,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 5),
              Text(
                subtitle!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

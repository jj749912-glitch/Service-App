import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../app.dart' show Professional;
import '../locations.dart';
import 'design.dart';
import 'customer_data.dart';

class SolarBackdrop extends StatelessWidget {
  final Widget child;
  final double height;
  const SolarBackdrop({super.key, required this.child, this.height = 270});
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: height,
        child: Image.asset(
          'assets/mobile/solar-house.png',
          fit: BoxFit.cover,
          alignment: Alignment.centerRight,
          cacheWidth: 1000,
        ),
      ),
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF00417E).withValues(alpha: .96),
                const Color(0xFF006AB1).withValues(alpha: .65),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
      child,
    ],
  );
}

class MobileHeader extends StatelessWidget {
  final String city;
  final ValueChanged<String>? onCity;
  final VoidCallback onNotifications;
  const MobileHeader({
    super.key,
    required this.city,
    this.onCity,
    required this.onNotifications,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      18,
      MediaQuery.paddingOf(context).top + 12,
      12,
      12,
    ),
    child: Row(
      children: [
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: const ServeBrand(size: 22),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.only(left: 9, right: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            color: Colors.white.withValues(alpha: .13),
            border: Border.all(color: Colors.white.withValues(alpha: .35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on, size: 16, color: Colors.white),
              const SizedBox(width: 3),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: city,
                  dropdownColor: const Color(0xFF086AAB),
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white,
                    size: 19,
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Poppins',
                    fontSize: 10,
                  ),
                  items: serviceCities
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text('$c, Kerala'),
                        ),
                      )
                      .toList(),
                  onChanged: onCity == null
                      ? null
                      : (v) {
                          if (v != null) onCity!(v);
                        },
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onNotifications,
          tooltip: 'Notifications',
          icon: const Icon(
            Icons.notifications_none_rounded,
            color: Colors.white,
            size: 25,
          ),
          visualDensity: VisualDensity.compact,
        ),
      ],
    ),
  );
}

class CareSection extends StatelessWidget {
  final String title;
  final VoidCallback? onAll;
  const CareSection(this.title, {super.key, this.onAll});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 17,
              letterSpacing: -.55,
            ),
          ),
        ),
        if (onAll != null)
          TextButton(
            onPressed: onAll,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              minimumSize: const Size(0, 32),
            ),
            child: const Row(
              children: [
                Text('View All', style: TextStyle(fontSize: 11)),
                SizedBox(width: 5),
                Icon(Icons.arrow_forward, size: 15),
              ],
            ),
          ),
      ],
    ),
  );
}

class ProfessionalAvatar extends StatelessWidget {
  final String name;
  final double size;
  final bool round;
  const ProfessionalAvatar(
    this.name, {
    super.key,
    this.size = 65,
    this.round = false,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(round ? size : 16),
      gradient: const LinearGradient(
        colors: [Color(0xFFE0F2FF), Color(0xFFB7DDF9)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Center(
      child: Text(
        name.trim().isEmpty
            ? '?'
            : name
                  .trim()
                  .split(RegExp(r'\s+'))
                  .take(2)
                  .map((w) => w[0])
                  .join()
                  .toUpperCase(),
        style: TextStyle(
          fontSize: size * .29,
          fontWeight: FontWeight.w600,
          color: serveBlue,
        ),
      ),
    ),
  );
}

class RatingLine extends StatelessWidget {
  final Professional professional;
  final bool compact;
  const RatingLine(this.professional, {super.key, this.compact = false});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.star_rounded, color: Color(0xFFFFB600), size: 19),
      const SizedBox(width: 3),
      Text(
        professional.reviewCount == 0
            ? 'New'
            : professional.rating.toStringAsFixed(1),
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      ),
      if (professional.reviewCount > 0)
        Text(
          compact
              ? ' (${professional.reviewCount})'
              : ' (${professional.reviewCount} reviews)',
          style: const TextStyle(color: serveMuted, fontSize: 10),
        ),
    ],
  );
}

class ProfessionalTile extends StatelessWidget {
  final Professional professional;
  final VoidCallback onTap;
  final bool compact;
  final bool saved;
  final VoidCallback? onSave, onBook;
  const ProfessionalTile(
    this.professional, {
    super.key,
    required this.onTap,
    this.compact = false,
    this.saved = false,
    this.onSave,
    this.onBook,
  });
  @override
  Widget build(BuildContext context) {
    final p = professional;
    if (compact) {
      return SizedBox(
        width: 156,
        child: ServeCard(
          padding: const EdgeInsets.all(11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ProfessionalAvatar(p.name, size: 53),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Column(
                      children: [
                        if (p.verified) const _VerifiedBadge(),
                        const SizedBox(height: 5),
                        RatingLine(p, compact: true),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                p.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                displayService(p.service),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: serveMuted, fontSize: 10),
              ),
              const SizedBox(height: 5),
              Text(
                '${p.city} · ${p.years} years',
                style: const TextStyle(color: serveMuted, fontSize: 10),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '₹${p.rate}/hr',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onTap,
                    tooltip: 'View ${p.name}',
                    icon: const Icon(
                      Icons.arrow_forward,
                      color: Colors.white,
                      size: 17,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: serveBlue,
                      minimumSize: const Size(30, 30),
                      padding: const EdgeInsets.all(7),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    return ServeCard(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfessionalAvatar(p.name, size: 76),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (p.verified) const _VerifiedBadge(),
                    const SizedBox(height: 6),
                    Text(
                      p.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      displayService(p.service),
                      style: const TextStyle(color: serveMuted, fontSize: 11),
                    ),
                    const SizedBox(height: 5),
                    RatingLine(p),
                    const SizedBox(height: 6),
                    Text(
                      '${p.city} · ${p.years} years experience',
                      style: const TextStyle(color: serveMuted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              if (onSave != null)
                IconButton(
                  onPressed: onSave,
                  tooltip: saved ? 'Unsave professional' : 'Save professional',
                  icon: Icon(
                    saved ? Icons.bookmark : Icons.bookmark_outline,
                    color: serveBlue,
                    size: 21,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '₹${p.rate} / hour',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              YellowButton(
                onBook == null ? 'View' : 'Book',
                onPressed: onBook == null
                    ? onTap
                    : p.verified
                    ? onBook
                    : null,
              ),
            ],
          ),
          if (onBook != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.person_outline, size: 18),
                label: const Text('View Profile & Reviews'),
              ),
            ),
        ],
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFDDFBF0),
      borderRadius: BorderRadius.circular(30),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.verified, size: 12, color: Color(0xFF03A85E)),
        SizedBox(width: 3),
        Flexible(
          child: Text(
            'Verified',
            style: TextStyle(color: Color(0xFF086738), fontSize: 9),
          ),
        ),
      ],
    ),
  );
}

class SolarOffer extends StatelessWidget {
  final bool plan;
  final VoidCallback onTap;
  const SolarOffer({super.key, this.plan = false, required this.onTap});
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(22),
    child: Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/mobile/solar-house.png',
            fit: BoxFit.cover,
            alignment: Alignment.centerRight,
            cacheWidth: 900,
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF003C5C),
                  const Color(0xFF006C9E).withValues(alpha: .85),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan ? 'Annual' : 'Clean Panels',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 23,
                    height: 1.15,
                    letterSpacing: -.7,
                  ),
                ),
                Text(
                  plan ? 'Solar Care Plan' : 'Brighter Savings',
                  style: TextStyle(
                    color: plan ? serveYellow : Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 22,
                    height: 1.15,
                    letterSpacing: -.7,
                  ),
                ),
                const SizedBox(height: 7),
                SizedBox(
                  width: 205,
                  child: Text(
                    plan
                        ? 'Regular cleaning · Preventive checks\nCare for a brighter tomorrow'
                        : 'Professional solar panel cleaning\nfor higher efficiency',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                YellowButton(
                  plan ? 'View Plan Details' : 'Book a Service',
                  onPressed: onTap,
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

LatLng cityCenter(String city) => city == 'Thrissur'
    ? const LatLng(10.5276, 76.2144)
    : const LatLng(9.9816, 76.2999);

class ServiceAreaMap extends StatefulWidget {
  final String city;
  final bool enabled;
  const ServiceAreaMap({super.key, required this.city, this.enabled = true});
  @override
  State<ServiceAreaMap> createState() => _ServiceAreaMapState();
}

class _ServiceAreaMapState extends State<ServiceAreaMap> {
  final controller = MapController();
  @override
  void didUpdateWidget(covariant ServiceAreaMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.city != widget.city && widget.enabled) {
      controller.move(cityCenter(widget.city), 12.6);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      if (widget.enabled)
        FlutterMap(
          mapController: controller,
          options: MapOptions(
            initialCenter: cityCenter(widget.city),
            initialZoom: 12.6,
            minZoom: 8,
            maxZoom: 18,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.solarcare',
            ),
            const SimpleAttributionWidget(
              source: Text(
                'OpenStreetMap contributors',
                style: TextStyle(fontSize: 9),
              ),
              alignment: Alignment.bottomLeft,
            ),
          ],
        )
      else
        Container(
          color: const Color(0xFFE8F1F4),
          child: Center(
            child: Text(
              '${widget.city} service area',
              style: const TextStyle(color: serveMuted),
            ),
          ),
        ),
      Positioned(
        right: 12,
        top: 18,
        child: Column(
          children: [
            IconButton(
              onPressed: widget.enabled
                  ? () => controller.move(cityCenter(widget.city), 12.6)
                  : null,
              tooltip: 'Center on service area',
              icon: const Icon(Icons.my_location, color: serveNavy),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 9),
            IconButton(
              onPressed: widget.enabled
                  ? () => controller.move(
                      controller.camera.center,
                      controller.camera.zoom + .5,
                    )
                  : null,
              tooltip: 'Zoom in',
              icon: const Icon(Icons.add, color: serveNavy),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.all(14),
              ),
            ),
          ],
        ),
      ),
      Positioned(
        top: 18,
        left: 12,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .92),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            '$cityLabel · Service area',
            style: const TextStyle(fontSize: 11, color: serveNavy),
          ),
        ),
      ),
    ],
  );
  String get cityLabel => widget.city;
}

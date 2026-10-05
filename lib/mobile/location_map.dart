import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'design.dart';

class LocationPin {
  final String id, label;
  final LatLng point;
  final VoidCallback? onTap;
  const LocationPin(this.id, this.label, this.point, {this.onTap});
}

class LocationMap extends StatelessWidget {
  final LatLng center;
  final List<LocationPin> pins;
  final ValueChanged<LatLng>? onPick;
  final bool enabled;
  const LocationMap({
    super.key,
    required this.center,
    this.pins = const [],
    this.onPick,
    this.enabled = true,
  });
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: enabled
        ? FlutterMap(
            key: ValueKey('${center.latitude}-${center.longitude}'),
            options: MapOptions(
              initialCenter: center,
              initialZoom: 13,
              minZoom: 5,
              maxZoom: 18,
              onTap: onPick == null ? null : (_, point) => onPick!(point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.solarcare.solarserve',
              ),
              MarkerLayer(
                markers: pins
                    .map(
                      (pin) => Marker(
                        point: pin.point,
                        width: 96,
                        height: 72,
                        child: GestureDetector(
                          onTap: pin.onTap,
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: pin.id == 'customer'
                                      ? serveBlue
                                      : Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  pin.id == 'customer'
                                      ? Icons.person_pin_circle
                                      : Icons.engineering,
                                  color: pin.id == 'customer'
                                      ? Colors.white
                                      : serveBlue,
                                  size: 26,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Text(
                                  pin.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
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
        : ColoredBox(
            color: const Color(0xFFE5EFF6),
            child: Center(child: Text('${pins.length} selected location pins')),
          ),
  );
}

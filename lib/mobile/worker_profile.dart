import 'package:flutter/material.dart';
import '../app.dart' show Professional;
import 'components.dart';
import 'customer_app.dart' show MobileBottomBar;
import 'customer_data.dart';
import 'design.dart';
import 'booking_pages.dart';

class MobileWorkerProfile extends StatefulWidget {
  final Professional professional;
  final MobileCustomerApi api;
  final String city;
  final ValueChanged<int> onTab;
  const MobileWorkerProfile({
    super.key,
    required this.professional,
    required this.api,
    required this.city,
    required this.onTab,
  });
  @override
  State<MobileWorkerProfile> createState() => _MobileWorkerProfileState();
}

class _MobileWorkerProfileState extends State<MobileWorkerProfile> {
  List<Map<String, dynamic>> reviews = [];
  bool loading = true, expanded = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final rows = await widget.api.reviews(widget.professional.id);
      if (mounted) {
        setState(() {
          reviews = rows;
          loading = false;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'Could not load reviews. Please retry.';
        });
      }
    }
  }

  Future<void> schedule({bool earliest = false}) async {
    final booked = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => MobileSchedulePage(
          professional: widget.professional,
          api: widget.api,
          city: widget.city,
          earliest: earliest,
        ),
      ),
    );
    if (booked != null && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.professional;
    return Scaffold(
      body: SingleChildScrollView(
        child: SolarBackdrop(
          height: 225,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MobileHeader(
                city: widget.city,
                onNotifications: () =>
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Your booking updates are available in My Jobs.',
                        ),
                      ),
                    ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 3, 18, 17),
                child: PageHeading(
                  'Worker Profile',
                  onBack: () => Navigator.pop(context),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(15, 15, 15, 20),
                decoration: const BoxDecoration(
                  color: serveBackground,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ProfessionalAvatar(
                          p.name,
                          size: MediaQuery.sizeOf(context).width < 370
                              ? 112
                              : 130,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      p.name,
                                      style: const TextStyle(
                                        fontSize: 23,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: -.6,
                                      ),
                                    ),
                                  ),
                                  if (p.verified)
                                    const Icon(
                                      Icons.verified,
                                      color: serveBlue,
                                      size: 19,
                                    ),
                                ],
                              ),
                              Text(
                                displayService(p.service),
                                style: const TextStyle(
                                  color: serveMuted,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              RatingLine(p),
                              const SizedBox(height: 13),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.assignment_outlined,
                                    color: serveNavy,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${p.reviewCount}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const Text(
                                          'Customer Reviews',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: serveMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.emoji_events_outlined,
                                    color: serveNavy,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${p.years} Years',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const Text(
                                          'Experience',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: serveMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (p.verified)
                      const Wrap(
                        spacing: 8,
                        runSpacing: 7,
                        children: [
                          Chip(
                            avatar: Icon(
                              Icons.verified_user,
                              color: Color(0xFF04A358),
                              size: 18,
                            ),
                            label: Text(
                              'Verified Professional',
                              style: TextStyle(fontSize: 10),
                            ),
                            backgroundColor: Color(0xFFE8F5FF),
                          ),
                        ],
                      ),
                    const SizedBox(height: 15),
                    const CareSection('Services Offered'),
                    Row(
                      children: [
                        ServeCard(
                          child: Column(
                            children: [
                              ServiceArt(p.service, size: 54),
                              const SizedBox(height: 5),
                              Text(
                                displayService(p.service),
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Serving ${p.city}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '₹${p.rate} / hour',
                                style: const TextStyle(
                                  fontSize: 19,
                                  color: serveBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    CareSection('About ${p.name.split(' ').first}'),
                    Text(
                      p.bio,
                      maxLines: expanded ? null : 4,
                      overflow: expanded ? null : TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: serveMuted,
                        fontSize: 12,
                        height: 1.7,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => setState(() => expanded = !expanded),
                        child: Text(
                          expanded ? 'Read Less ⌃' : 'Read More ⌄',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                    const CareSection('Service Pricing'),
                    ServeCard(
                      child: Row(
                        children: [
                          ServiceArt(p.service, size: 58),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayService(p.service),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '₹${p.rate} / hour',
                                  style: const TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                const Text(
                                  'Choose 1–4 hours when scheduling.\nMaterials and extra work require your agreement.',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: serveMuted,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const CareSection('Customer Reviews'),
                    if (loading) const LinearProgressIndicator(),
                    if (error != null)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              error!,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          TextButton(
                            onPressed: load,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    if (!loading && error == null && reviews.isEmpty)
                      const ServeCard(
                        child: Text(
                          'No written reviews yet.',
                          style: TextStyle(color: serveMuted, fontSize: 12),
                        ),
                      ),
                    ...reviews.map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: ServeCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      r['author_name'] as String,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.star,
                                    color: serveYellow,
                                    size: 16,
                                  ),
                                  Text(' ${r['rating']}'),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                r['body'] as String,
                                style: const TextStyle(
                                  color: serveMuted,
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: YellowButton(
                            'Book Now',
                            onPressed: p.verified
                                ? () => schedule(earliest: true)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: p.verified ? schedule : null,
                            icon: const Icon(Icons.calendar_month, size: 19),
                            label: const Text(
                              'Schedule',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: MobileBottomBar(current: 0, onSelect: widget.onTab),
    );
  }
}

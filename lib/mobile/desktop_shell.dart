import 'package:flutter/material.dart';
import '../app.dart' show Professional;
import '../locations.dart';
import '../service_offering.dart';
import 'components.dart';
import 'customer_data.dart';
import 'design.dart';

class DesktopCustomerShell extends StatelessWidget {
  final int current, unread;
  final String name, city;
  final ValueChanged<int> onSelect;
  final ValueChanged<String> onCity;
  final ValueChanged<String> onSearch;
  final VoidCallback onBooking, onNotifications, onAdmin, onSignOut;
  final Widget home, content;
  const DesktopCustomerShell({
    super.key,
    required this.current,
    required this.name,
    required this.city,
    required this.unread,
    required this.onSelect,
    required this.onCity,
    required this.onSearch,
    required this.onBooking,
    required this.onNotifications,
    required this.onAdmin,
    required this.onSignOut,
    required this.home,
    required this.content,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        Container(
          height: 82,
          padding: const EdgeInsets.symmetric(horizontal: 26),
          color: Colors.white,
          child: Row(
            children: [
              const SizedBox(
                width: 190,
                child: ServeBrand(dark: true, size: 23),
              ),
              const SizedBox(width: 20),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: city,
                  items: serviceCities
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(
                            '$c, Kerala',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (c) => onCity(c!),
                ),
              ),
              const SizedBox(width: 25),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Find a service or professional',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: onSearch,
                ),
              ),
              const SizedBox(width: 20),
              IconButton(
                onPressed: onNotifications,
                tooltip: 'Notifications',
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread'),
                  child: const Icon(Icons.notifications_none, color: serveBlue),
                ),
              ),
              const SizedBox(width: 15),
              TextButton.icon(
                onPressed: () => onSelect(4),
                icon: const Icon(Icons.account_circle_outlined),
                label: Text(name.isEmpty ? 'Profile' : name),
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 210,
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 20,
                ),
                child: Column(
                  children: [
                    for (final entry in [
                      (0, 'Home', Icons.home_outlined),
                      (1, 'Booking', Icons.event_note),
                      (2, 'Jobs', Icons.work_outline),
                      (3, 'Messages', Icons.chat_bubble_outline),
                      (4, 'Profile', Icons.person_outline),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          selected: current == entry.$1,
                          selectedTileColor: const Color(0xFFE2F0FF),
                          leading: Icon(entry.$3, size: 21),
                          title: Text(entry.$2),
                          onTap: entry.$1 == 1
                              ? onBooking
                              : () => onSelect(entry.$1),
                        ),
                      ),
                    const Spacer(),
                    ListTile(
                      leading: const Icon(Icons.admin_panel_settings_outlined),
                      title: const Text('Admin Dashboard'),
                      onTap: onAdmin,
                    ),
                    ListTile(
                      leading: const Icon(Icons.help_outline),
                      title: const Text('Help & Support'),
                      onTap: () => onSelect(3),
                    ),
                    ListTile(
                      leading: const Icon(Icons.settings_outlined),
                      title: const Text('Account Settings'),
                      onTap: () => onSelect(4),
                    ),
                    OutlinedButton.icon(
                      onPressed: onSignOut,
                      icon: const Icon(Icons.logout),
                      label: const Text('Sign Out'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: serveNavy,
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: serveNavy),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: current == 0
                      ? home
                      : Container(
                          decoration: BoxDecoration(
                            color: serveBackground,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: content,
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class DesktopHome extends StatelessWidget {
  final String name, city;
  final List<Professional> professionals;
  final VoidCallback onBook;
  final ValueChanged<String> onService;
  final ValueChanged<Professional> onProfile;
  const DesktopHome({
    super.key,
    required this.name,
    required this.city,
    required this.professionals,
    required this.onBook,
    required this.onService,
    required this.onProfile,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        DateTime.now().hour < 12 ? 'Good Morning,' : 'Welcome Back,',
        style: const TextStyle(fontSize: 18),
      ),
      Text(
        '${name.isEmpty ? 'Welcome Home' : name.split(' ').first} ☀',
        style: const TextStyle(fontSize: 31, fontWeight: FontWeight.w600),
      ),
      const Text(
        'Brighter Homes. Greener Tomorrows.',
        style: TextStyle(color: serveMuted),
      ),
      const SizedBox(height: 22),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 255, child: SolarOffer(onTap: onBook)),
                const SizedBox(height: 22),
                const CareSection('Our Services'),
                LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: offeredServices
                          .map(
                            (s) => Padding(
                              padding: EdgeInsets.only(
                                right: s == offeredServices.last ? 0 : 8,
                              ),
                              child: SizedBox(
                                width: ((constraints.maxWidth - 40) / 6).clamp(
                                  86,
                                  160,
                                ),
                                child: InkWell(
                                  onTap: () => onService(s),
                                  child: ServeCard(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 14,
                                    ),
                                    child: Column(
                                      children: [
                                        ServiceArt(s, size: 58),
                                        const SizedBox(height: 8),
                                        Text(
                                          displayService(s),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 10),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                ServeCard(
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: serveBlue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Choose your address in $city to see available professionals nearby.',
                        ),
                      ),
                      FilledButton(
                        onPressed: onBook,
                        child: const Text('Book a Service'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 4,
            child: ServeCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CareSection('Professionals in your area'),
                  if (professionals.isEmpty)
                    const EmptyCare(
                      icon: Icons.engineering_outlined,
                      title: 'No approved professionals yet',
                      message:
                          'Real worker profiles appear after registration and administrator approval.',
                    ),
                  for (final p in professionals.take(6))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ProfessionalAvatar(p.name, size: 45),
                      title: Text(p.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final option in p.offerings)
                            Text(
                              '${displayService(option.service)} · ₹${option.rate}/hr',
                              style: const TextStyle(fontSize: 12),
                            ),
                          RatingLine(p),
                        ],
                      ),
                      trailing: IconButton(
                        onPressed: () => onProfile(p),
                        icon: const Icon(
                          Icons.arrow_circle_right,
                          color: serveBlue,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

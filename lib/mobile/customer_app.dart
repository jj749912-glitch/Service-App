import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app.dart' show Professional, categories;
import '../locations.dart';
import 'components.dart';
import 'customer_data.dart';
import 'design.dart';
import 'worker_profile.dart';
import 'booking_pages.dart';

const mobileServices = [
  'Solar cleaning',
  'Solar inspection',
  'Electrical',
  'Plumbing',
  'Home cleaning',
  'Solar repair',
];

class MobileCustomerApp extends StatefulWidget {
  final MobileCustomerApi? api;
  final bool mapsEnabled;
  const MobileCustomerApp({super.key, this.api, this.mapsEnabled = true});
  @override
  State<MobileCustomerApp> createState() => _MobileCustomerAppState();
}

class _MobileCustomerAppState extends State<MobileCustomerApp> {
  late final MobileCustomerApi api;
  CustomerSnapshot data = const CustomerSnapshot();
  String city = initialCity,
      category = 'All services',
      query = '',
      sort = 'Recommended',
      jobFilter = 'Ongoing',
      messageFilter = 'All';
  int tab = 0;
  bool loading = true, onlySaved = false;
  String? error;
  Set<String> saved = {};
  String get savedKey => 'mobile_saved_${data.userId}';
  int get savedCount => data.professionals
      .where((p) => p.verified && saved.contains(p.id))
      .length;
  Timer? refresh;
  @override
  void initState() {
    super.initState();
    api = widget.api ?? SupabaseMobileCustomerApi(Supabase.instance.client);
    load();
    refresh = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!loading && mounted) load(quiet: true);
    });
  }

  @override
  void dispose() {
    refresh?.cancel();
    super.dispose();
  }

  Future<void> load({bool quiet = false}) async {
    if (!quiet) setState(() => loading = true);
    try {
      final results = await Future.wait<dynamic>([
        api.load(),
        SharedPreferences.getInstance(),
      ]);
      if (!mounted) return;
      setState(() {
        data = results[0] as CustomerSnapshot;
        saved =
            ((results[1] as SharedPreferences).getStringList(savedKey) ?? [])
                .toSet();
        loading = false;
        error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error =
              'Could not load your account. Check your connection and retry.';
        });
      }
    }
  }

  void selectTab(int value) => setState(() {
    tab = value;
    query = '';
    onlySaved = false;
  });
  void explore({String service = 'All services', bool favourites = false}) =>
      setState(() {
        tab = 1;
        category = service;
        onlySaved = favourites;
        query = '';
      });
  List<Professional> get professionals {
    final rows = data.professionals
        .where(
          (p) =>
              p.verified &&
              p.city == city &&
              (category == 'All services' || p.service == category) &&
              '${p.name} ${p.service}'.toLowerCase().contains(
                query.toLowerCase(),
              ) &&
              (!onlySaved || saved.contains(p.id)),
        )
        .toList();
    if (sort == 'Price: low to high') {
      rows.sort((a, b) => a.rate.compareTo(b.rate));
    } else {
      rows.sort((a, b) => b.rating.compareTo(a.rating));
    }
    return rows;
  }

  Future<void> save(Professional p) async {
    setState(() {
      saved.contains(p.id) ? saved.remove(p.id) : saved.add(p.id);
    });
    await (await SharedPreferences.getInstance()).setStringList(
      savedKey,
      saved.toList(),
    );
  }

  void notice(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
  Future<void> openProfile(Professional p) async {
    final booked = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MobileWorkerProfile(
          professional: p,
          api: api,
          city: city,
          onTab: (value) {
            Navigator.of(context).pop();
            selectTab(value);
          },
        ),
      ),
    );
    if (booked == true && mounted) {
      selectTab(2);
      setState(() => jobFilter = 'Scheduled');
      await load();
    }
  }

  Future<void> bookFromExplore(Professional p) async {
    final booked = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) =>
            MobileSchedulePage(professional: p, api: api, city: city),
      ),
    );
    if (booked != null && mounted) {
      selectTab(2);
      setState(() => jobFilter = 'Scheduled');
      await load();
    }
  }

  Future<void> filters() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: serveBackground,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Find your professional',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 19),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: categories
                      .map(
                        (service) => ChoiceChip(
                          label: Text(displayService(service)),
                          selected: category == service,
                          selectedColor: const Color(0xFFDCEEFF),
                          onSelected: (_) {
                            setState(() => category = service);
                            update(() {});
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: sort,
                  decoration: const InputDecoration(labelText: 'Sort by'),
                  items: ['Recommended', 'Top rated', 'Price: low to high']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => sort = v);
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: YellowButton(
                    'Show Professionals',
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() => tab = 1);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> notifications() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: serveBackground,
    isScrollControlled: true,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Booking Updates',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            if (data.bookings.isEmpty)
              const EmptyCare(
                icon: Icons.notifications_none,
                title: 'No updates yet',
                message: 'Updates from your service requests will appear here.',
              ),
            ...data.bookings
                .take(5)
                .map(
                  (b) => ListTile(
                    leading: const Icon(
                      Icons.event_available,
                      color: serveBlue,
                    ),
                    title: Text(displayService(b['service'] as String)),
                    subtitle: Text(
                      '${b['professional_name']} · ${bookingStatus(b)}',
                    ),
                  ),
                ),
          ],
        ),
      ),
    ),
  );
  void unavailable(
    String title,
    String message, {
    VoidCallback? action,
    String? actionLabel,
  }) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: serveBackground,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: EmptyCare(
          icon: Icons.solar_power_outlined,
          title: title,
          message: message,
          action: action == null
              ? null
              : YellowButton(
                  actionLabel ?? 'Explore Services',
                  onPressed: () {
                    Navigator.pop(ctx);
                    action();
                  },
                ),
        ),
      ),
    ),
  );
  void plan() => unavailable(
    'Annual Solar Care Plan',
    'Annual care plans are not available yet. You can request individual services from an approved professional.',
    action: () => explore(service: 'Solar cleaning'),
    actionLabel: 'Book Individual Service',
  );
  Widget header() => MobileHeader(
    city: city,
    onCity: (value) => setState(() => city = value),
    onNotifications: notifications,
  );
  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
    child: Scaffold(
      body: RefreshIndicator(
        onRefresh: load,
        child: SingleChildScrollView(
          key: ValueKey(tab),
          physics: const AlwaysScrollableScrollPhysics(),
          child: SolarBackdrop(
            height: tab == 0 ? 325 : 220,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header(),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: ServeCard(
                      color: const Color(0xFFFFF0DA),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              error!,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          TextButton(
                            onPressed: load,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (loading)
                  const LinearProgressIndicator(
                    minHeight: 2,
                    color: serveYellow,
                    backgroundColor: Colors.transparent,
                  ),
                switch (tab) {
                  0 => home(),
                  1 => nearby(),
                  2 => jobs(),
                  3 => messages(),
                  _ => profile(),
                },
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: MobileBottomBar(current: tab, onSelect: selectTab),
    ),
  );

  Widget home() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 2, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              greeting,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            Row(
              children: [
                Flexible(
                  child: Text(
                    data.name.isEmpty
                        ? 'Welcome Home'
                        : data.name.split(' ').first,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.wb_sunny_rounded,
                  color: serveYellow,
                  size: 26,
                ),
              ],
            ),
            const Text(
              'Brighter Homes. Greener Tomorrows.',
              style: TextStyle(color: Colors.white, fontSize: 11),
            ),
            const SizedBox(height: 13),
            GlassSearch(
              hint: 'Search for services, professionals...',
              onChanged: (v) => setState(() => query = v),
              onFilter: filters,
            ),
            if (query.isNotEmpty) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() => tab = 1),
                child: const Text(
                  'See Search Results →',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: SolarOffer(onTap: () => explore(service: 'Solar cleaning')),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CareSection('Our Services', onAll: explore),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: mobileServices
                    .map(
                      (service) => SizedBox(
                        width: 72,
                        child: InkWell(
                          onTap: () => explore(service: service),
                          borderRadius: BorderRadius.circular(16),
                          child: Column(
                            children: [
                              ServeCard(
                                padding: const EdgeInsets.all(4),
                                radius: 17,
                                child: ServiceArt(service, size: 45),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                displayService(service),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 10,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 19),
            CareSection('Nearby Professionals', onAll: explore),
            if (professionals.isEmpty)
              EmptyCare(
                icon: Icons.groups_outlined,
                title: 'No professionals in $city yet',
                message:
                    'Approved local professionals will appear here with their actual hourly rates and reviews.',
                action: TextButton(
                  onPressed: explore,
                  child: const Text('Explore Services →'),
                ),
              )
            else
              SizedBox(
                height:
                    220 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 2),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: professionals.length,
                  separatorBuilder: (_, index) => const SizedBox(width: 9),
                  itemBuilder: (_, i) => ProfessionalTile(
                    professionals[i],
                    compact: true,
                    onTap: () => openProfile(professionals[i]),
                  ),
                ),
              ),
            const SizedBox(height: 17),
            SolarOffer(plan: true, onTap: plan),
          ],
        ),
      ),
    ],
  );
  String get greeting => DateTime.now().hour < 12
      ? 'Good Morning,'
      : DateTime.now().hour < 18
      ? 'Good Afternoon,'
      : 'Good Evening,';
  Widget nearby() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
        child: GlassSearch(
          hint: 'Search by area, service or professional...',
          onChanged: (v) => setState(() => query = v),
          onFilter: filters,
        ),
      ),
      SizedBox(
        height: 54,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Row(
            children: ['All services', ...mobileServices]
                .map(
                  (service) => Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: FilterChip(
                      label: Text(
                        displayService(service),
                        style: TextStyle(
                          color: category == service ? Colors.white : serveNavy,
                          fontSize: 11,
                        ),
                      ),
                      selected: category == service,
                      showCheckmark: false,
                      avatar: service == 'All services'
                          ? const Icon(Icons.apps, size: 17, color: serveBlue)
                          : ServiceArt(service, size: 21),
                      onSelected: (_) => setState(() => category = service),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: 240,
        child: ServiceAreaMap(city: city, enabled: widget.mapsEnabled),
      ),
      Container(
        decoration: const BoxDecoration(
          color: serveBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 35,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFBEC8D5),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    onlySaved ? 'Saved Professionals' : 'Nearby Professionals',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.6,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: filters,
                  tooltip: 'Sort professionals',
                  icon: const Icon(Icons.swap_vert, color: serveBlue),
                ),
              ],
            ),
            Text(
              'Verified professionals serving $city',
              style: const TextStyle(fontSize: 11, color: serveMuted),
            ),
            const SizedBox(height: 15),
            if (professionals.isEmpty)
              EmptyCare(
                icon: Icons.person_search_outlined,
                title: onlySaved
                    ? 'No saved professionals here'
                    : 'No professionals found',
                message:
                    'Try another service or city, or check back as local professionals join.',
              ),
            ...professionals.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ProfessionalTile(
                  p,
                  onTap: () => openProfile(p),
                  saved: saved.contains(p.id),
                  onSave: () => save(p),
                  onBook: () => bookFromExplore(p),
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
  bool matchesJob(Map<String, dynamic> b, String filter) {
    final status = b['status'];
    if (filter == 'Completed') return status == 'completed';
    if (filter == 'Cancelled') return status == 'cancelled';
    if (status != 'requested' && status != 'accepted') return false;
    final started = DateTime.parse(
      b['starts_at'] as String,
    ).isBefore(DateTime.now());
    return filter == 'Ongoing'
        ? status == 'accepted' && started
        : status == 'requested' || !started;
  }

  Widget jobs() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(18, 7, 18, 24),
        child: PageHeading(
          'My Jobs',
          subtitle: 'Manage and track all your solar services\nin one place.',
        ),
      ),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: const BoxDecoration(
          color: serveBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['Ongoing', 'Scheduled', 'Completed', 'Cancelled']
                    .map(
                      (filter) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          showCheckmark: false,
                          label: Text(
                            '$filter (${data.bookings.where((b) => matchesJob(b, filter)).length})',
                            style: TextStyle(
                              fontSize: 10,
                              color: filter == jobFilter
                                  ? Colors.white
                                  : serveNavy,
                            ),
                          ),
                          selected: filter == jobFilter,
                          onSelected: (_) => setState(() => jobFilter = filter),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
            if (!data.bookings.any((b) => matchesJob(b, jobFilter)))
              EmptyCare(
                icon: Icons.assignment_outlined,
                title: 'No ${jobFilter.toLowerCase()} jobs',
                message:
                    'Your confirmed service requests will appear here. Choose a professional to book your first service.',
                action: YellowButton('Book a Service', onPressed: explore),
              ),
            ...data.bookings
                .where((b) => matchesJob(b, jobFilter))
                .map(
                  (b) => Padding(
                    padding: const EdgeInsets.only(bottom: 13),
                    child: jobCard(b),
                  ),
                ),
          ],
        ),
      ),
    ],
  );
  Widget jobCard(Map<String, dynamic> b) {
    final starts = DateTime.parse(b['starts_at'] as String).toLocal();
    final ends = DateTime.parse(b['ends_at'] as String).toLocal();
    return ServeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ServeCard(
                color: const Color(0xFFEAF4FE),
                padding: const EdgeInsets.all(6),
                child: ServiceArt(b['service'] as String, size: 66),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayService(b['service'] as String),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      bookingStatus(b),
                      style: TextStyle(
                        color: b['status'] == 'completed'
                            ? const Color(0xFF05965B)
                            : serveBlue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '₹${b['total']}',
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              ProfessionalAvatar(b['professional_name'] as String, size: 36),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  b['professional_name'] as String,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          detail(Icons.calendar_month, formatDate(starts)),
          detail(Icons.schedule, '${formatTime(starts)} – ${formatTime(ends)}'),
          detail(Icons.location_on_outlined, b['address'] as String),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => openBooking(b),
                  icon: const Icon(Icons.description_outlined, size: 19),
                  label: const Text(
                    'View Details',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => openTracking(b),
                  icon: const Icon(Icons.location_on, size: 19),
                  label: const Text(
                    'Track Live',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget detail(IconData icon, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: serveNavy),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              color: serveMuted,
              height: 1.5,
            ),
          ),
        ),
      ],
    ),
  );
  Future<void> openBooking(Map<String, dynamic> b) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MobileBookingDetails(booking: b, api: api, city: city),
      ),
    );
    if (mounted) await load();
  }

  void openTracking(Map<String, dynamic> b) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => MobileTrackingPage(
        booking: b,
        api: api,
        city: city,
        mapsEnabled: widget.mapsEnabled,
      ),
    ),
  );
  Widget messages() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 7, 18, 20),
        child: Column(
          children: [
            const PageHeading(
              'Messages',
              subtitle: 'Chat with professionals and get support',
            ),
            const SizedBox(height: 13),
            GlassSearch(
              hint: 'Search messages, professionals...',
              onChanged: (v) => setState(() => query = v),
              onFilter: () => unavailable(
                'Message Filters',
                'There are no conversations to filter yet.',
              ),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ServeCard(
              color: const Color(0xFFDFF1FF),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFC4E5FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.support_agent,
                      size: 35,
                      color: serveBlue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Need Help?',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Get support for bookings\nand service queries.',
                          style: TextStyle(
                            fontSize: 10,
                            color: serveMuted,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  YellowButton(
                    'Chat Now',
                    onPressed: () => unavailable(
                      'Support Chat',
                      'In-app chat is not available yet. Your service requests and status updates remain available in My Jobs.',
                      action: () => selectTab(2),
                      actionLabel: 'View My Jobs',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            Row(
              children: ['All', 'Professionals', 'Support']
                  .map(
                    (filter) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: ChoiceChip(
                          label: SizedBox(
                            width: double.infinity,
                            child: Text(
                              filter,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                color: messageFilter == filter
                                    ? Colors.white
                                    : serveNavy,
                              ),
                            ),
                          ),
                          selected: messageFilter == filter,
                          showCheckmark: false,
                          onSelected: (_) =>
                              setState(() => messageFilter = filter),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 17),
            EmptyCare(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'No conversations yet',
              message:
                  'Messaging is not available yet. View booking updates in My Jobs.',
              action: TextButton(
                onPressed: () => selectTab(2),
                child: const Text('View Booking Updates →'),
              ),
            ),
          ],
        ),
      ),
    ],
  );
  Widget profile() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(18, 7, 18, 23),
        child: PageHeading(
          'Profile',
          subtitle: 'Manage your account, bookings\nand solar journey.',
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: ServeCard(
          padding: const EdgeInsets.all(16),
          radius: 25,
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProfessionalAvatar(data.name, size: 74, round: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.name.isEmpty ? 'Your Account' : data.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (data.phone.isNotEmpty)
                          detail(Icons.phone_outlined, data.phone),
                        if (data.email.isNotEmpty)
                          detail(Icons.mail_outline, data.email),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: editName,
                    tooltip: 'Edit profile',
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: serveBlue,
                      size: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ServeCard(
                      color: const Color(0xFFFFDB4D),
                      padding: const EdgeInsets.all(10),
                      radius: 13,
                      child: const Row(
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            color: Color(0xFFAD6F00),
                            size: 24,
                          ),
                          SizedBox(width: 7),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Customer Account',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Ready to book',
                                  style: TextStyle(fontSize: 9),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ServeCard(
                      color: const Color(0xFFE0FBF4),
                      padding: const EdgeInsets.all(10),
                      radius: 13,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.bookmark,
                            color: Color(0xFF04A25B),
                            size: 24,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$savedCount',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                const Text(
                                  'Saved Experts',
                                  style: TextStyle(fontSize: 9),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 17, 14, 25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CareSection('Account Overview', onAll: () => selectTab(2)),
            Row(
              children: [
                overview(
                  Icons.calendar_month,
                  '${data.bookings.length}',
                  'Total Bookings',
                  'Your service history',
                ),
                const SizedBox(width: 7),
                overview(
                  Icons.verified_user,
                  'No Plan',
                  'Care Plan',
                  'Not enrolled',
                ),
                const SizedBox(width: 7),
                overview(
                  Icons.check_circle_outline,
                  '${data.bookings.where((b) => b['status'] == 'completed').length}',
                  'Completed',
                  'Finished jobs',
                ),
              ],
            ),
            const SizedBox(height: 18),
            const CareSection('Quick Actions'),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 7,
              mainAxisSpacing: 7,
              childAspectRatio:
                  1.3 / MediaQuery.textScalerOf(context).scale(1).clamp(1, 2),
              children: [
                quick(
                  Icons.solar_power,
                  'My Solar\nSystems',
                  () => unavailable(
                    'My Solar Systems',
                    'Solar-system registration is not available yet. You can include system details when requesting a service.',
                  ),
                ),
                quick(Icons.location_on, 'Saved\nAddresses', addresses),
                quick(
                  Icons.account_balance_wallet,
                  'Payment\nMethods',
                  () => unavailable(
                    'Payment Methods',
                    'Online payments are not enabled. No payment is collected when you send a service request.',
                  ),
                ),
                quick(Icons.notifications, 'Notifications', notifications),
                quick(Icons.support_agent, 'Help &\nSupport', help),
                quick(Icons.settings, 'Settings', settings),
              ],
            ),
            const SizedBox(height: 17),
            SolarOffer(plan: true, onTap: plan),
            const SizedBox(height: 15),
            if (data.admin)
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pushNamed('/admin'),
                icon: const Icon(Icons.admin_panel_settings_outlined),
                label: const Text('Admin Dashboard'),
              ),
            TextButton.icon(
              onPressed: signOut,
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
            ),
          ],
        ),
      ),
    ],
  );
  Widget overview(
    IconData icon,
    String value,
    String title,
    String note,
  ) => Expanded(
    child: ServeCard(
      padding: const EdgeInsets.all(10),
      radius: 15,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 27, color: serveBlue),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
            ),
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(note, style: const TextStyle(fontSize: 8, color: serveMuted)),
        ],
      ),
    ),
  );
  Widget quick(IconData icon, String label, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: ServeCard(
      padding: const EdgeInsets.all(10),
      radius: 16,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: serveBlue, size: 29),
          const SizedBox(height: 7),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9, height: 1.35),
          ),
        ],
      ),
    ),
  );
  Future<void> editName() async {
    final controller = TextEditingController(text: data.name);
    final form = GlobalKey<FormState>();
    bool busy = false;
    String? failure;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Edit Profile'),
          content: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: controller,
                  enabled: !busy,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (v) => (v?.trim().length ?? 0) < 3
                      ? 'Enter your full name.'
                      : null,
                ),
                if (failure != null)
                  Text(failure!, style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      update(() => busy = true);
                      try {
                        await api.rename(controller.text);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) await load();
                      } catch (_) {
                        if (ctx.mounted) {
                          update(() {
                            busy = false;
                            failure = 'Could not save your name. Please retry.';
                          });
                        }
                      }
                    },
              child: Text(busy ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 350));
    controller.dispose();
  }

  void addresses() {
    final rows = data.bookings.map((b) => b['address'] as String).toSet();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: serveBackground,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Service Addresses',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 15),
              if (rows.isEmpty)
                const EmptyCare(
                  icon: Icons.location_on_outlined,
                  title: 'No service addresses yet',
                  message:
                      'Addresses you enter when booking a service will appear here.',
                ),
              ...rows
                  .take(6)
                  .map(
                    (address) => ListTile(
                      leading: const Icon(Icons.location_on, color: serveBlue),
                      title: Text(
                        address,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  void help() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: serveBackground,
    builder: (_) => const SafeArea(
      child: Padding(
        padding: EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Help & Support',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            ExpansionTile(
              title: Text('How do bookings work?'),
              children: [
                Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Choose a verified professional, select a future date and time, enter your address and send a request. The professional must accept it.',
                  ),
                ),
              ],
            ),
            ExpansionTile(
              title: Text('How are prices calculated?'),
              children: [
                Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'The estimate is the professional’s hourly labour rate multiplied by your selected duration. Materials and extra work require your agreement. No online payment is collected.',
                  ),
                ),
              ],
            ),
            ExpansionTile(
              title: Text('How do I cancel?'),
              children: [
                Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Open My Jobs and View Details. Pending requests can be cancelled there.',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  void settings() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: serveBackground,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Settings',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Edit Profile'),
              onTap: () {
                Navigator.pop(ctx);
                editName();
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign Out'),
              onTap: () {
                Navigator.pop(ctx);
                signOut();
              },
            ),
          ],
        ),
      ),
    ),
  );
  Future<void> signOut() async {
    try {
      await api.signOut();
    } catch (_) {
      if (mounted) notice('Could not sign out. Please retry.');
    }
  }
}

class MobileBottomBar extends StatelessWidget {
  final int current;
  final ValueChanged<int> onSelect;
  const MobileBottomBar({
    super.key,
    required this.current,
    required this.onSelect,
  });
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      boxShadow: [
        BoxShadow(
          color: Color(0x0E164E80),
          blurRadius: 16,
          offset: Offset(0, -5),
        ),
      ],
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        child: Row(
          children: List.generate(
            5,
            (i) => Expanded(
              child: Semantics(
                selected: current == i,
                button: true,
                label: ['Home', 'Explore', 'Jobs', 'Messages', 'Profile'][i],
                excludeSemantics: true,
                child: InkWell(
                  onTap: () => onSelect(i),
                  borderRadius: BorderRadius.circular(21),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(21),
                      color: current == i
                          ? const Color(0xFFF0F8FF)
                          : Colors.transparent,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          [
                            current == 0 ? Icons.home : Icons.home_outlined,
                            Icons.explore_outlined,
                            current == 2
                                ? Icons.assignment
                                : Icons.assignment_outlined,
                            current == 3
                                ? Icons.chat_bubble
                                : Icons.chat_bubble_outline,
                            current == 4 ? Icons.person : Icons.person_outline,
                          ][i],
                          size: 26,
                          color: current == i
                              ? serveBlue
                              : const Color(0xFF3E567A),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          ['Home', 'Explore', 'Jobs', 'Messages', 'Profile'][i],
                          style: TextStyle(
                            fontSize: 9,
                            color: current == i ? serveBlue : serveMuted,
                            fontWeight: current == i
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

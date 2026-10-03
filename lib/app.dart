import 'locations.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_gate.dart';
import 'app_theme.dart';
import 'backend_config.dart';
export 'app_theme.dart';
export 'backend_config.dart';
import 'review_dialog.dart';
import 'admin_portal.dart';
import 'mobile/customer_app.dart';
import 'mobile/design.dart';
import 'mobile/login.dart';

class SolarCareApp extends StatelessWidget {
  final AppAuthApi? auth;
  final WidgetBuilder? homeBuilder;
  final bool? mobile;
  const SolarCareApp({super.key, this.auth, this.homeBuilder, this.mobile});
  bool get useMobile =>
      mobile ??
      (kIsWeb ||
          defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: useMobile ? 'SolarServe' : 'SolarCare',
    debugShowCheckedModeBanner: false,
    scrollBehavior: const SolarServeScrollBehavior(),
    theme: useMobile ? solarServeTheme() : solarCareTheme(),
    builder: useMobile
        ? (context, child) => SolarServeFrame(child: child!)
        : null,
    home: AuthGate(
      api: auth,
      signedInBuilder:
          homeBuilder ??
          (_) => useMobile ? const MobileCustomerApp() : const Marketplace(),
      signedOutBuilder: useMobile ? (api) => MobileLoginScreen(api: api) : null,
    ),
    routes: {
      '/admin': (_) => AuthGate(
        api: auth,
        signedInBuilder: (_) => const AdminPortal(),
        signedOutBuilder: useMobile
            ? (api) => MobileLoginScreen(api: api)
            : null,
      ),
    },
  );
}

class Professional {
  final String id, name, service, city, bio;
  final int rate, years, reviewCount;
  final double rating;
  final bool verified;
  const Professional(
    this.id,
    this.name,
    this.service,
    this.rate,
    this.rating,
    this.years,
    this.bio, {
    this.city = initialCity,
    this.verified = false,
    this.reviewCount = 0,
  });
  factory Professional.fromJson(Map<String, dynamic> j) => Professional(
    j['id'],
    j['name'],
    j['service'],
    j['hourly_rate'],
    (j['rating'] as num).toDouble(),
    j['years'],
    j['bio'],
    city: j['city'],
    verified: j['verified'],
    reviewCount: j['review_count'] ?? 0,
  );
}

const categories = [
  'All services',
  'Solar cleaning',
  'Solar inspection',
  'Solar repair',
  'Electrical',
  'Plumbing',
  'Home cleaning',
];
const categoryIcons = [
  Icons.grid_view_rounded,
  Icons.wb_sunny_outlined,
  Icons.fact_check_outlined,
  Icons.build_outlined,
  Icons.bolt,
  Icons.water_drop_outlined,
  Icons.cleaning_services_outlined,
];

class Marketplace extends StatefulWidget {
  final bool useBackend;
  const Marketplace({super.key, this.useBackend = true});
  @override
  State<Marketplace> createState() => _MarketplaceState();
}

class _MarketplaceState extends State<Marketplace> {
  List<Professional> pros = [];
  List<Map<String, dynamic>> bookings = [];
  Set<String> saved = {};
  String category = 'All services',
      query = '',
      sort = 'Recommended',
      city = initialCity;
  int tab = 0;
  bool loading = false;
  bool refreshing = false;
  Timer? bookingRefresh;
  @override
  void initState() {
    super.initState();
    load();
    if (widget.useBackend && connected) {
      bookingRefresh = Timer.periodic(const Duration(seconds: 15), (_) {
        if (mounted && !refreshing) load(quiet: true);
      });
    }
  }

  @override
  void dispose() {
    bookingRefresh?.cancel();
    super.dispose();
  }

  void notice(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  Future<void> load({bool quiet = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      saved = (prefs.getStringList('saved') ?? []).toSet();
    });
    if (widget.useBackend && connected) {
      if (refreshing) return;
      refreshing = true;
      if (!quiet) setState(() => loading = true);
      try {
        final rows = await Supabase.instance.client
            .from('professional_directory')
            .select()
            .eq('verified', true)
            .order('name');
        final jobs = Supabase.instance.client.auth.currentUser == null
            ? <Map<String, dynamic>>[]
            : await Supabase.instance.client
                  .from('bookings')
                  .select()
                  .eq(
                    'customer_id',
                    Supabase.instance.client.auth.currentUser!.id,
                  )
                  .order('starts_at');
        if (mounted) {
          setState(() {
            pros = rows.map(Professional.fromJson).toList();
            bookings = jobs;
          });
        }
      } catch (_) {
        if (mounted && !quiet) {
          notice('Could not load live data. Check your connection and retry.');
        }
      }
      refreshing = false;
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> toggleSave(Professional p) async {
    setState(() {
      saved.contains(p.id) ? saved.remove(p.id) : saved.add(p.id);
    });
    await (await SharedPreferences.getInstance()).setStringList(
      'saved',
      saved.toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 850;
    final filtered = pros
        .where(
          (p) =>
              p.city == city &&
              (category == 'All services' || p.service == category) &&
              '${p.name} ${p.service}'.toLowerCase().contains(
                query.toLowerCase(),
              ) &&
              (tab != 2 || saved.contains(p.id)),
        )
        .toList();
    if (sort == 'Price: low to high') {
      filtered.sort((a, b) => a.rate.compareTo(b.rate));
    }
    if (sort == 'Top rated' || sort == 'Recommended') {
      filtered.sort((a, b) => b.rating.compareTo(a.rating));
    }
    return Scaffold(
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (v) {
                setState(() => tab = v);
                load();
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.explore_outlined),
                  label: 'Explore',
                ),
                NavigationDestination(
                  icon: Icon(Icons.calendar_month_outlined),
                  label: 'Bookings',
                ),
                NavigationDestination(
                  icon: Icon(Icons.favorite_border),
                  label: 'Saved',
                ),
              ],
            ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: wide ? 48 : 20,
                vertical: 18,
              ),
              child: Row(
                children: [
                  Image.asset(
                    'assets/branding/logo.png',
                    width: 48,
                    height: 48,
                    fit: BoxFit.contain,
                    semanticLabel: 'SolarCare logo',
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'solarcare',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      color: ink,
                      letterSpacing: -1,
                    ),
                  ),
                  if (wide) ...[
                    const SizedBox(width: 60),
                    ...['Explore', 'My bookings', 'Saved'].asMap().entries.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(right: 20),
                        child: TextButton(
                          onPressed: () {
                            setState(() => tab = e.key);
                            load();
                          },
                          child: Text(
                            e.value,
                            style: TextStyle(
                              color: tab == e.key ? green : Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  IconButton(
                    tooltip: 'Your account',
                    onPressed: account,
                    icon: const CircleAvatar(
                      backgroundColor: Color(0xFFEDF2E7),
                      child: Icon(Icons.person_outline, color: green),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: load,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1260),
                      child: Padding(
                        padding: EdgeInsets.all(wide ? 38 : 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 19,
                                  color: green,
                                ),
                                const SizedBox(width: 6),
                                DropdownButton<String>(
                                  value: city,
                                  underline: const SizedBox(),
                                  items: serviceCities
                                      .map(
                                        (s) => DropdownMenuItem(
                                          value: s,
                                          child: Text(s),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (s) => setState(() => city = s!),
                                ),
                                const Spacer(),
                                Text(
                                  connected ? 'LIVE' : 'SETUP',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    letterSpacing: 1.4,
                                    color: green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            if (tab == 0) ...[
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(wide ? 40 : 26),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE6EFDC),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'GOOD ENERGY STARTS AT HOME',
                                            style: TextStyle(
                                              fontSize: 10,
                                              letterSpacing: 2,
                                              color: green,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 18),
                                          Text(
                                            'A little care.\nA brighter tomorrow.',
                                            style: TextStyle(
                                              fontSize: wide ? 46 : 32,
                                              fontWeight: FontWeight.w800,
                                              height: 1.1,
                                              letterSpacing: -1.5,
                                              color: ink,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          const Text(
                                            'From solar panels to the little things at home.\nFind trusted local experts, on your schedule.',
                                            style: TextStyle(
                                              color: Color(0xFF4C6758),
                                              fontSize: 15,
                                              height: 1.6,
                                            ),
                                          ),
                                          const SizedBox(height: 24),
                                          FilledButton(
                                            onPressed: () => setState(
                                              () => category = 'Solar cleaning',
                                            ),
                                            child: const Text(
                                              'Find a solar expert  ↗',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (wide)
                                      const SizedBox(
                                        width: 370,
                                        height: 225,
                                        child: CustomPaint(
                                          painter: SolarIllustration(),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 22),
                              const Wrap(
                                spacing: 26,
                                runSpacing: 10,
                                children: [
                                  TrustLabel(
                                    Icons.verified_user_outlined,
                                    'Verified professionals',
                                  ),
                                  TrustLabel(
                                    Icons.receipt_long_outlined,
                                    'Clear hourly pricing',
                                  ),
                                  TrustLabel(
                                    Icons.event_available_outlined,
                                    'Book on your schedule',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 28),
                              TextField(
                                onChanged: (s) => setState(() => query = s),
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.search),
                                  hintText: 'Search services or professionals',
                                ),
                              ),
                              const SizedBox(height: 26),
                              heading('One home. Every kind of care.'),
                              const SizedBox(height: 16),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: categories
                                      .asMap()
                                      .entries
                                      .map(
                                        (e) => Padding(
                                          padding: const EdgeInsets.only(
                                            right: 10,
                                          ),
                                          child: ChoiceChip(
                                            showCheckmark: false,
                                            selectedColor: green,
                                            selected: category == e.value,
                                            avatar: Icon(
                                              categoryIcons[e.key],
                                              size: 20,
                                              color: category == e.value
                                                  ? Colors.white
                                                  : green,
                                            ),
                                            label: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 10,
                                                  ),
                                              child: Text(
                                                e.value,
                                                style: TextStyle(
                                                  color: category == e.value
                                                      ? Colors.white
                                                      : ink,
                                                ),
                                              ),
                                            ),
                                            onSelected: (_) => setState(
                                              () => category = e.value,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                              const SizedBox(height: 32),
                            ],
                            if (tab != 1) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        heading(
                                          tab == 2
                                              ? 'Your trusted shortlist'
                                              : 'Great people. Great service.',
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '${filtered.length} professionals in $city',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (wide) sortPicker(),
                                ],
                              ),
                              if (!wide) sortPicker(),
                              const SizedBox(height: 22),
                              if (loading) const LinearProgressIndicator(),
                              if (filtered.isEmpty && !loading)
                                empty(
                                  'No professionals here yet',
                                  'Try another service or city, or save a professional from Explore.',
                                ),
                              LayoutBuilder(
                                builder: (context, c) {
                                  final count = c.maxWidth > 950
                                      ? 3
                                      : c.maxWidth > 600
                                      ? 2
                                      : 1;
                                  return Wrap(
                                    spacing: 20,
                                    runSpacing: 20,
                                    children: filtered
                                        .map(
                                          (p) => SizedBox(
                                            width:
                                                (c.maxWidth -
                                                    (count - 1) * 20) /
                                                count,
                                            child: proCard(p),
                                          ),
                                        )
                                        .toList(),
                                  );
                                },
                              ),
                            ] else ...[
                              heading('My bookings'),
                              const SizedBox(height: 20),
                              if (bookings.isEmpty)
                                empty(
                                  'Your next service starts here',
                                  'Find an expert and choose a time that works for you.',
                                ),
                              ...bookings.map(bookingCard),
                            ],
                            const SizedBox(height: 40),
                            const Divider(),
                            const SizedBox(height: 16),
                            const Text(
                              'SOLAR FIRST. HOME ALWAYS.',
                              style: TextStyle(
                                fontSize: 11,
                                letterSpacing: 2,
                                fontWeight: FontWeight.bold,
                                color: green,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Local professionals. Verified skills. Reviews from completed services.',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget heading(String s) => Text(
    s,
    style: const TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      color: ink,
      letterSpacing: -.5,
    ),
  );
  Widget sortPicker() => DropdownButton<String>(
    value: sort,
    underline: const SizedBox(),
    items: [
      'Recommended',
      'Price: low to high',
      'Top rated',
    ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
    onChanged: (s) => setState(() => sort = s!),
  );
  Widget empty(String title, String subtitle) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(36),
    child: Column(
      children: [
        const Icon(Icons.wb_sunny_outlined, size: 42, color: green),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(subtitle, textAlign: TextAlign.center),
      ],
    ),
  );
  Widget avatar(Professional p) => CircleAvatar(
    radius: 29,
    backgroundColor: const Color(0xFFE9ECD9),
    child: Text(
      p.name.split(' ').map((s) => s[0]).take(2).join(),
      style: const TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
    ),
  );
  Widget proCard(Professional p) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE2E8DF)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            avatar(p),
            const Spacer(),
            IconButton(
              tooltip: 'Save professional',
              onPressed: () => toggleSave(p),
              icon: Icon(
                saved.contains(p.id) ? Icons.favorite : Icons.favorite_border,
                color: saved.contains(p.id) ? green : Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          p.name,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(p.service, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 14),
        Row(
          children: [
            const Icon(Icons.star_rounded, color: Color(0xFFE9AD36), size: 20),
            Text(
              p.reviewCount == 0
                  ? ' New · '
                  : ' ${p.rating} (${p.reviewCount}) ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Flexible(
              child: Text(
                '· ${p.years} years experience',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (p.verified)
          TrustLabel(Icons.verified_outlined, 'Verified specialist'),
        const SizedBox(height: 18),
        const Divider(),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '₹${p.rate} / hour',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
            OutlinedButton(
              onPressed: () => profile(p),
              child: const Text('View profile'),
            ),
          ],
        ),
      ],
    ),
  );
  Future<void> profile(Professional p) async {
    List<Map<String, dynamic>> reviews = [];
    if (widget.useBackend && connected) {
      try {
        reviews = await Supabase.instance.client
            .from('reviews')
            .select()
            .eq('professional_id', p.id);
      } catch (_) {
        if (mounted) notice('Reviews could not be loaded.');
      }
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.sizeOf(ctx).height * .8,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              avatar(p),
              const SizedBox(height: 18),
              heading(p.name),
              Text('${p.service} · ${p.city}'),
              const SizedBox(height: 16),
              if (p.verified)
                TrustLabel(
                  Icons.verified_user_outlined,
                  'Identity and skills verified',
                ),
              const SizedBox(height: 20),
              Text(p.bio, style: const TextStyle(fontSize: 16, height: 1.6)),
              const SizedBox(height: 20),
              Text(
                '₹${p.rate}/hour · ${p.years} years experience',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: green,
                ),
              ),
              const SizedBox(height: 28),
              heading(
                p.reviewCount == 0
                    ? 'Customer reviews'
                    : 'Customer reviews · ${p.rating} ★',
              ),
              const SizedBox(height: 12),
              if (reviews.isEmpty) const Text('No written reviews yet.'),
              ...reviews.map(
                (r) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text("${r['author_name']} · ${r['rating']} ★"),
                  subtitle: Text(r['body']),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    book(p);
                  },
                  child: const Text('Choose a time & book  →'),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Hourly labour estimate. Materials and extra work require your agreement.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> book(Professional p) async {
    if (!connected) {
      notice('Connect Supabase to book a professional.');
      return;
    }
    if (connected && Supabase.instance.client.auth.currentUser == null) {
      await account();
      if (Supabase.instance.client.auth.currentUser == null) return;
    }
    if (!mounted) return;
    var day = DateTime.now().add(const Duration(days: 1));
    var hour = 10;
    var duration = 1;
    var busy = false;
    final address = TextEditingController(), notes = TextEditingController();
    final form = GlobalKey<FormState>();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            12,
            24,
            MediaQuery.viewInsetsOf(ctx).bottom + 30,
          ),
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                heading('Make time for your home'),
                const SizedBox(height: 12),
                Text('${p.name} · ${p.service} · ₹${p.rate}/hour'),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_month),
                  label: Text('${day.day}/${day.month}/${day.year}'),
                  onPressed: busy
                      ? null
                      : () async {
                          final selected = await showDatePicker(
                            context: ctx,
                            initialDate: day,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 90),
                            ),
                          );
                          if (selected != null) update(() => day = selected);
                        },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: hour,
                        decoration: const InputDecoration(
                          labelText: 'Start time',
                        ),
                        items: [8, 9, 10, 11, 12, 13, 14, 15, 16, 17]
                            .map(
                              (h) => DropdownMenuItem(
                                value: h,
                                child: Text('$h:00'),
                              ),
                            )
                            .toList(),
                        onChanged: busy ? null : (v) => update(() => hour = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: duration,
                        decoration: const InputDecoration(
                          labelText: 'Duration',
                        ),
                        items: [1, 2, 3, 4]
                            .map(
                              (h) => DropdownMenuItem(
                                value: h,
                                child: Text('$h hour${h == 1 ? '' : 's'}'),
                              ),
                            )
                            .toList(),
                        onChanged: busy
                            ? null
                            : (v) => update(() => duration = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: address,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Full service address',
                  ),
                  validator: (v) => (v?.trim().length ?? 0) < 10
                      ? 'Enter a full address (10+ characters)'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notes,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                Text(
                  'Estimated labour: ₹${p.rate * duration}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: green,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'No payment collected. Requests need professional acceptance.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            if (!form.currentState!.validate()) return;
                            final start = DateTime(
                              day.year,
                              day.month,
                              day.day,
                              hour,
                            );
                            if (!start.isAfter(DateTime.now())) {
                              notice('Please choose a future time.');
                              return;
                            }
                            update(() => busy = true);
                            try {
                              final record = <String, dynamic>{
                                'professional_id': p.id,
                                'professional_name': p.name,
                                'service': p.service,
                                'starts_at': start.toUtc().toIso8601String(),
                                'hours': duration,
                                'address': address.text.trim(),
                                'notes': notes.text.trim(),
                                'total': p.rate * duration,
                                'status': 'requested',
                              };
                              record['customer_id'] =
                                  Supabase.instance.client.auth.currentUser!.id;
                              await Supabase.instance.client
                                  .from('bookings')
                                  .insert(record);
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) {
                                setState(() => tab = 1);
                                await load();
                                if (mounted) {
                                  notice('Booking request sent.');
                                }
                              }
                            } catch (_) {
                              if (ctx.mounted) update(() => busy = false);
                              if (mounted) {
                                notice(
                                  'Booking not saved. This slot may be unavailable; try another time.',
                                );
                              }
                            }
                          },
                    child: Text(busy ? 'Sending…' : 'Request booking'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 400));
    address.dispose();
    notes.dispose();
  }

  Widget bookingCard(Map<String, dynamic> b) {
    final date = DateTime.parse(b['starts_at']).toLocal();
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            heading(b['professional_name']),
            const SizedBox(height: 8),
            Text(
              "${b['service']} · ${date.day}/${date.month}/${date.year} at ${date.hour}:00",
            ),
            const SizedBox(height: 8),
            Text(b['address']),
            const SizedBox(height: 12),
            Wrap(
              spacing: 20,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text("₹${b['total']} · ${b['hours']} hour(s)"),
                Chip(label: Text(b['status'])),
                if (b['status'] == 'completed')
                  TextButton(
                    onPressed: () async {
                      final submitted = await showDialog<bool>(
                        context: context,
                        builder: (_) => ReviewDialog(booking: b),
                      );
                      if (submitted == true) {
                        await load();
                        if (mounted) notice('Your review was published.');
                      }
                    },
                    child: const Text('Write a review'),
                  ),
                if (b['status'] == 'requested')
                  TextButton(
                    onPressed: () async {
                      try {
                        await Supabase.instance.client.rpc(
                          'cancel_booking',
                          params: {'booking_id': b['id']},
                        );
                        await load();
                      } catch (_) {
                        if (mounted) notice('Could not cancel this request.');
                      }
                    },
                    child: const Text('Cancel request'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> account() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;
    bool admin;
    try {
      admin = await SupabaseAdminApi(client).hasAccess();
    } catch (_) {
      if (mounted) notice('Could not check account access. Please retry.');
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Your account'),
        content: Text(user.email ?? 'Signed in'),
        actions: [
          if (admin)
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                await Navigator.of(context).pushNamed('/admin');
                if (mounted) await load();
              },
              icon: const Icon(Icons.admin_panel_settings_outlined),
              label: const Text('Admin dashboard'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await client.auth.signOut(scope: SignOutScope.local);
              } catch (_) {
                if (mounted) notice('Could not sign out. Please retry.');
              }
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class TrustLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const TrustLabel(this.icon, this.label, {super.key});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 17, color: green),
      const SizedBox(width: 6),
      Flexible(
        child: Text(label, style: const TextStyle(fontSize: 12, color: green)),
      ),
    ],
  );
}

class SolarIllustration extends CustomPainter {
  const SolarIllustration();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    canvas.drawCircle(
      const Offset(290, 48),
      32,
      p..color = const Color(0xFFE8BE51),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(55, 115, 260, 105),
        const Radius.circular(6),
      ),
      p..color = const Color(0xFFF9FBF3),
    );
    canvas.drawPath(
      Path()
        ..moveTo(20, 120)
        ..lineTo(155, 28)
        ..lineTo(345, 120)
        ..close(),
      p..color = const Color(0xFF406B54),
    );
    canvas.drawPath(
      Path()
        ..moveTo(85, 93)
        ..lineTo(155, 44)
        ..lineTo(276, 100)
        ..lineTo(196, 100)
        ..close(),
      p..color = const Color(0xFFB5D9E4),
    );
    p
      ..color = const Color(0xFF507D87)
      ..strokeWidth = 2;
    for (var i = 0; i < 4; i++) {
      canvas.drawLine(
        Offset(111 + i * 22, 76 - i * 7),
        Offset(153 + i * 26, 100),
        p,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(174, 150, 45, 70),
        const Radius.circular(4),
      ),
      p..color = const Color(0xFFB9CDB0),
    );
    canvas.drawRect(
      const Rect.fromLTWH(83, 145, 50, 42),
      p..color = const Color(0xFFBCD9E0),
    );
    canvas.drawCircle(
      const Offset(317, 174),
      34,
      p..color = const Color(0xFF6F9863),
    );
    canvas.drawRect(
      const Rect.fromLTWH(313, 180, 8, 42),
      p..color = const Color(0xFF406B54),
    );
    canvas.drawOval(
      const Rect.fromLTWH(20, 212, 330, 12),
      p..color = const Color(0xFFCDDDC0),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

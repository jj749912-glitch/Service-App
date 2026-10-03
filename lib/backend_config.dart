// Public client configuration. These defaults also work when a developer runs
// Flutter without --dart-define. Never put secret or service-role keys here.
const backendUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://usgdrzubndfvfarkklok.supabase.co',
);
const backendKey = String.fromEnvironment(
  'SUPABASE_KEY',
  defaultValue: 'sb_publishable_2AXuUmyOm7QI69CIkJXWyQ_GDwAqSJ-',
);
const customerSite = 'https://servicefacilities.netlify.app/';
const workerSite = '${customerSite}worker/';
bool get connected => backendUrl.isNotEmpty && backendKey.isNotEmpty;

# SolarCare

A solar-first property maintenance marketplace built with Flutter and Supabase. Responsive customer experience for Android, iOS, web, and Windows.

## Repository setup

Clone `https://github.com/jj749912-glitch/Service-App.git` and open its root directory. Install Flutter 3.44.4 (Dart 3.12.2) or a compatible newer version, then follow the commands below. Android requires the Android SDK; iOS requires macOS and Xcode.

Source code, platform projects, tests and database reference scripts are included. Generated `build/` output, local SDK paths, signing credentials and `dist/` delivery packages are excluded from Git. Rebuild deployment packages using the instructions below. The included Supabase configuration contains only a public publishable key; SMTP credentials must be entered directly in Supabase settings.

## Try it

```powershell
flutter pub get
flutter run -d chrome --dart-define-from-file=supabase-config.json
```

The supplied config uses only a public Supabase publishable key. It connects to the `solarcare-test` project in Mumbai. Never put a secret or service-role key in the app.

The app uses real Supabase data only. Without cloud configuration it shows setup guidance and an empty directory; it never creates simulated accounts, profiles, reviews or bookings. Sign-up requires confirming your email before signing in. Favourites are stored locally, while bookings and reviews are stored only in Supabase.

Before admitting customers outside your Supabase organization, configure an email provider in Authentication → Email → SMTP. Supabase's built-in sender only delivers to organization team addresses. Keep email confirmation enabled and set the production Site URL in Auth URL Configuration. SMTP credentials belong in Supabase settings, never in this Flutter app. See https://supabase.com/docs/guides/auth/auth-smtp.

## Implemented

The app header and Android, iOS, web and Windows icons use the supplied solar/home maintenance artwork. The original is preserved at `assets/branding/app-icon.png`; the app uses its resized `logo.png`. To regenerate icon files, install Node.js and Sharp (`npm install --no-save sharp`), then run `node tools/generate-icons.cjs`. Web maskable icons include safe padding. This updates image assets only.

See `BREVO_SETUP.md` for the free SMTP setup steps. Enter SMTP credentials directly in Supabase, never in the source code.

- Responsive solar-first home screen with a custom solar illustration.
- Solar cleaning, inspection and repair, plus electrical, plumbing and cleaning categories.
- Search by name/service, city filtering, hourly rates, ratings and sorting.
- Professional profiles, written reviews and locally saved favourites.
- Reviews may be submitted once per completed booking; ratings are calculated from those reviews. Unreviewed professionals display “New”.
- Date, time, 1–4 hour duration, address and notes for booking requests.
- Email sign-up, sign-in, persistent Supabase sessions and sign-out.
- My bookings with request cancellation.
- Professional applications with administrator-controlled verification, and a worker workspace to accept/decline requests and complete services after their scheduled end.
- Server-calculated prices, future-date validation and overlapping-slot exclusion.
- Row-level security: public directory/reviews; private customer/provider booking access. Customers can only cancel their own pending requests.

## Real data and pilot boundaries

No dummy records are seeded. Ernakulam and Thrissur are the available locations, with Ernakulam selected initially for customers and professional applications. The directory starts empty and lists only registered, verified professionals. Every professional must have a real Supabase account; every review must reference a completed booking owned by its author. Automated database verification uses rolled-back transactions and leaves no test records.

Payments, live tracking, notifications and an admin console remain to be implemented. Actual identity and qualification checks must be performed by your administrator: confirm the applicant's identity, validate service qualifications, confirm service area and agreed rate, then approve the profile in Supabase. An applicant cannot approve themselves. Use the account menu → Professional workspace to apply or manage jobs. Clients cannot edit verification or stored ratings; the directory calculates ratings from completed-service reviews through an RLS-respecting view.

## Free-tier testing

Project creation was quoted at $0/month. Supabase currently includes 500 MB database, 1 GB file storage, 5 GB egress and 50,000 monthly active users. Free projects pause after one week of inactivity and have no automatic backups. These quotas suit a small pilot, not a capacity guarantee. Track actual usage in the dashboard. SMS, maps, payments, app-store accounts and hosting costs are separate; this MVP uses no paid integrations.

Pricing: https://supabase.com/pricing
Project: https://supabase.com/dashboard/project/usgdrzubndfvfarkklok

## Verification and builds

```powershell
flutter analyze
flutter test
flutter build web --dart-define-from-file=supabase-config.json
node preview.cjs
```

Preview: http://localhost:8080

```powershell
flutter build apk --dart-define-from-file=supabase-config.json
flutter build windows --dart-define-from-file=supabase-config.json
```

An Android debug APK was successfully built and is provided in `dist/SolarCare-android-test.apk`. Android startup logs confirmed Flutter and Supabase initialization. Emulator automation could not complete because its Dart debugging connection closed; full device flows are not yet verified. iOS requires macOS/Xcode and has not been built here. The Android release manifest includes internet access for Supabase.

For iOS on a Mac:

```sh
flutter pub get
flutter run -d <iphone-or-simulator-id> --dart-define-from-file=supabase-config.json
flutter build ios --no-codesign --dart-define-from-file=supabase-config.json
```

For an installable iOS distribution, open `ios/Runner.xcworkspace` in Xcode, select your Apple developer team and configure signing. The same Flutter screens and Supabase flows are used on both mobile platforms. iOS configuration targets iOS 13+, and Android release networking is enabled.

Android emulator checks:

```powershell
flutter test integration_test/mobile_test.dart -d emulator-5554 --dart-define-from-file=supabase-config.json
```

Database schema history is stored in the Supabase project's applied migrations. Local reference SQL files are in `backend/`; the later `real-data-only.sql` removes obsolete demo columns and enforces account-backed records. Do not apply these scripts to the already-initialized project.

## Netlify web deployment

The web version uses the same real accounts and data as Android/iOS. A custom domain is optional; use your site's `netlify.app` address for the initial pilot.

For GitHub-connected deployments, `netlify.toml` runs `bash tools/netlify-build.sh` and publishes `build/web`. Leave the base directory at the repository root and use `main` as the production branch. The script installs the verified Flutter 3.44.4 revision from the official Flutter repository and builds the release web app with the public Supabase configuration. No SMTP credentials are needed for the build. The first build downloads the Flutter tools and may take several minutes.

For a manual upload, build locally and deploy the **contents of `build/web`**, rather than the Flutter source folder. `netlify.toml` supplies the publish directory and SPA fallback. `_redirects` and `_headers` are also included in the web output for manual uploads.

The Netlify upload bundle is `dist/SolarCare-web-netlify.zip`. Unzip it, then upload the folder that contains `index.html` to your Netlify project. No secret server keys are included.

The repository is configured for Netlify deployment. Confirm the production deploy succeeds in your Netlify dashboard and use its assigned public URL below.

After Netlify assigns the public URL, set Supabase Authentication → URL Configuration → Site URL to that address. Hosting does not provide SMTP: configure an email sender separately before public signups. For a small pilot, an existing Gmail account can use SMTP with a Google app password if eligible and 2-Step Verification is enabled. Enter that credential directly in Supabase settings, not in source code or chat.

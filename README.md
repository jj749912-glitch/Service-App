# SolarServe

A solar-first property maintenance marketplace built with Flutter and Supabase. Responsive customer experience for Android, iOS, web, and Windows.

## Run both apps from terminals

Install Flutter 3.44.4, Git, Node.js and Android Studio with Android SDK. Add Flutter's `bin` directory to PATH (this machine uses `C:\flutter\bin`). Check setup with `flutter doctor -v`; enable USB debugging on a connected Android phone and approve its computer connection. `flutter devices` lists the device IDs to use below.

Customer app, terminal 1:

```powershell
Set-Location D:\Service_app\Solar-app
flutter pub get
flutter devices
flutter run -d <customer-device-id>
```

Worker app, terminal 2:

```powershell
Set-Location D:\Service_app\Solar-app\worker_app
flutter pub get
flutter run -d <worker-device-id>
```

Replace the device placeholders with IDs from `flutter devices`; the apps have separate package identifiers and can coexist on the same phone. Use a real confirmed customer account and a separate real worker account. Worker: register → confirm email → submit service/city/hourly-rate/profile → administrator verifies and approves. Customer: choose city/service → select the approved worker → choose a future date, duration and address → confirm request. Worker: refresh workspace → Accept or Decline. Customer: My Jobs → Scheduled or Cancelled → View Details. A decline is stored as `cancelled` and shown as Cancelled in both apps. Both apps poll every 15 seconds while open; pull to refresh the customer app or use Refresh in the worker app. Open booking details and tracking-status screens also poll and offer Refresh Status. These are booking status updates, not push notifications or live technician GPS.

## Build and install Android APKs

From the repository root:

```powershell
flutter build apk --debug
New-Item -ItemType Directory -Force dist
Copy-Item build\app\outputs\flutter-apk\app-debug.apk dist\SolarServe-android-test.apk
Set-Location worker_app
flutter build apk --debug
Copy-Item build\app\outputs\flutter-apk\app-debug.apk ..\dist\SolarCare-Pro-android-test.apk
Set-Location ..
```

Transfer each APK to an Android phone, open it and allow installation from the file app when prompted. These debug builds are for testing. For release outputs, run `flutter build apk --release` in each app directory; output is `build/app/outputs/flutter-apk/app-release.apk` inside that directory. Configure your own protected release keystore/signing before distributing publicly; never commit keystores or passwords. Android App Bundle builds use `flutter build appbundle --release`. A successful build does not establish that login has been tested on your physical phone.

## Upload source and update the hosted apps

From the repository root, review the files, run the checks, commit your intended changes and push:

```powershell
git status
git diff
flutter analyze
flutter test
git add README.md lib test integration_test backend assets pubspec.yaml pubspec.lock android ios windows preview.cjs netlify.toml tools worker_app
git diff --cached --stat
git commit -m "Update SolarServe customer and worker apps"
git push origin main
```

The configured repository is `https://github.com/jj749912-glitch/Service-App`. GitHub must authenticate your Git client; do not paste access tokens into commands or commit credentials. Generated APKs/build folders and signing secrets are excluded by `.gitignore`. If a cloned repository needs an origin, use `git remote add origin https://github.com/jj749912-glitch/Service-App.git`; do not add a second origin to this checkout.

Netlify builds both web apps from `main` using `tools/netlify-build.sh`. Project settings: base directory empty, build command `bash tools/netlify-build.sh`, publish directory `build/web`. In Netlify → servicefacilities → Deploys, wait for the matching Git commit to show **Published** before testing `https://servicefacilities.netlify.app/` and `https://servicefacilities.netlify.app/worker/`. A Git push alone is not proof of a successful deployment. No separate worker site is needed. Customers use the same SolarServe design on Android, iOS and the production website. Wide browser windows center the phone composition at up to 480 pixels. The worker app uses the same blue-and-yellow theme with its own approval and job-management workspace.

For a local combined web build:

```powershell
flutter build web --release
Set-Location worker_app
flutter build web --release --base-href=/worker/
Set-Location ..
New-Item -ItemType Directory -Force build\web\worker
Copy-Item worker_app\build\web\* build\web\worker -Recurse -Force
node preview.cjs
```

Open `http://localhost:8080/` for customers and `http://localhost:8080/worker/` for workers. The mobile-only preview below uses port 8081 and a separate build output.

## SolarServe mobile customer design

Android and iOS customers now use the SolarServe design: blue solar-home headers, Poppins typography, glossy service artwork, yellow booking buttons and five bottom tabs. The mobile screens cover Home, Explore, professional profiles, scheduling, booking details, tracking availability, My Jobs, Messages and Profile. The production customer website now uses the same screens. The separate worker login and workspace share SolarServe styling and retain their worker controls.

Explore supports booking directly from each approved professional's card. Choose the service and city, compare the recorded hourly rates, then choose Book to schedule that specific worker. View Profile & Reviews remains available before booking. A confirmed request saves to Supabase and appears in My Jobs; approval, slot and price checks still run on the server.

All professional details come from registered profiles. Only approved professionals appear in the customer directory. Hourly rates and years of experience use the recorded profile values; ratings and review counts come from completed-booking reviews. Missing professional photos use initials. No sample people, portraits, prices, reviews, completed-job counts, distances, arrival estimates or membership benefits are inserted from the design references. The worker workspace loads only the current worker's application, approval decision and assigned bookings.

Live technician GPS, chat, payments and annual care subscriptions are not implemented. Their mobile screens explain availability and never simulate activity. Explore shows the actual selected city's OpenStreetMap base map, with attribution, without invented worker markers. These community tiles are suitable for a small test; a larger launch should choose a suitable map provider. Login uses the existing email/password and email-confirmation flow; SMS OTP is not configured.

The Android testing package is `dist/SolarServe-android-test.apk`. iOS uses the same Flutter implementation but still requires a Mac/Xcode build and signing. Decorative mobile artwork was generated with the built-in image tool; complete prompts are recorded in `assets/mobile/ASSET_PROMPTS.md`. Poppins is bundled with its license in `assets/fonts/OFL.txt`.

For an isolated local browser preview of the mobile design, build `lib/mobile_preview.dart` to a separate directory. It retains real authentication; it is not the production web entry point:

```powershell
flutter build web -t lib/mobile_preview.dart --output=build/mobile-preview
node preview.cjs --mobile
```

Automated mobile checks use isolated in-memory responses and never create database records. They cover empty states, city/approval filtering, recorded profile values, booking confirmation, sign-in gating, Android/iOS layout selection and larger text. Run `flutter test`; optionally add `--dart-define=CAPTURE_MOBILE_UI=true` to save empty-state visual checks locally under `dist/mobile-ui/`.

## Repository setup

Clone `https://github.com/jj749912-glitch/Service-App.git` and open its root directory. Install Flutter 3.44.4 (Dart 3.12.2) or a compatible newer version, then follow the commands below. Android requires the Android SDK; iOS requires macOS and Xcode.

Source code, platform projects, tests and database reference scripts are included. Generated `build/` output, local SDK paths, signing credentials and `dist/` delivery packages are excluded from Git. Rebuild deployment packages using the instructions below. The included Supabase configuration contains only a public publishable key; SMTP credentials must be entered directly in Supabase settings.

## Try it

```powershell
flutter pub get
flutter run -d chrome --dart-define-from-file=supabase-config.json
```

The supplied config uses only a public Supabase publishable key. It connects to the `solarcare-test` project in Mumbai. Never put a secret or service-role key in the app.

The app uses real Supabase data only. The public connection settings are included by default so regular mobile builds open a working login screen; it never creates simulated accounts, profiles, reviews or bookings. Sign-up requires confirming your email before signing in. Favourites are stored locally, while bookings and reviews are stored only in Supabase.

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
- Protected admin dashboard for reviewing, approving, rejecting, editing and suspending workers; viewing users and bookings; cancelling active bookings with a reason; and reviewing an audit log.
- Server-calculated prices, future-date validation and overlapping-slot exclusion.
- Row-level security: public directory/reviews; private customer/provider booking access. Customers can only cancel their own pending requests.

## Real data and pilot boundaries

No dummy records are seeded. Ernakulam and Thrissur are the available locations, with Ernakulam selected initially for customers and professional applications. The directory starts empty and lists only registered, verified professionals. Every professional must have a real Supabase account; every review must reference a completed booking owned by its author. Automated database verification uses rolled-back transactions and leaves no test records.

Payments, live tracking and notifications remain to be implemented. Actual identity and qualification checks must be performed by your administrator: confirm the applicant's identity, validate service qualifications, confirm service area and agreed rate, then approve the profile in the admin dashboard. An applicant cannot approve themselves. Workers use the separate SolarServe Pro app at https://servicefacilities.netlify.app/worker/ to register, apply and manage jobs. Clients cannot edit verification or stored ratings; the directory calculates ratings from completed-service reviews through an RLS-respecting view.

## Admin and worker approval

Sign in with an owner-provisioned admin account. After sign-in, administrators use Your account → Admin dashboard. The web route is `https://servicefacilities.netlify.app/#/admin`, which checks authorization before reading data.

Workers create and confirm a real account, then submit their profile in Professional workspace. Approval is required once. Pending and rejected workers cannot receive jobs. Suspending an approved worker immediately removes their public listing and blocks reading or updating assigned jobs, including requests made with an existing access token. Existing bookings remain active for the administrator to review or cancel. Re-approval restores worker access. Worker decisions require a reason; approval also requires confirmation of identity, qualifications, service area and rate. Editing profiles does not rewrite existing booking prices.

Admin membership is stored in `private.app_admins`, never in user-editable metadata or the client. Only the project owner can provision or revoke membership through a trusted database connection. Use a confirmed account, look up its ID on the server, and insert that ID into the private membership table. The frontend exposes no membership-grant API and contains no service-role key. Membership and the auth session are checked on every admin request. Private worker reviews and audit entries have no direct client table privileges. Backend reference: `backend/admin-access.sql`. Regression checks: `backend/admin-access-check.sql` (entire transaction rolls back).

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

Android startup checks confirmed Flutter and Supabase initialization. A native read-only HTTPS check reached Supabase, but emulator connectivity was intermittent and physical-phone login is not yet verified. TLS verification remains enabled. iOS requires macOS/Xcode and has not been built here. The Android release manifest includes internet access for Supabase.

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

`backend/booking-workflow-check.sql` checks customer request creation, assigned-worker visibility, acceptance, decline, customer visibility of decisions, server pricing, overlap exclusion and unrelated-account isolation. `backend/admin-access-check.sql` checks approval, suspension and admin isolation. Both execute inside a transaction and roll back all temporary records; they are verification scripts, not seed data. UI tests use isolated in-memory responses only. The live directory currently has no registered professionals, so a real two-account appointment cannot be demonstrated until a genuine worker applies and is approved.

## Netlify web deployment

The web version uses the same real accounts and data as Android/iOS. A custom domain is optional; use your site's `netlify.app` address for the initial pilot.

For GitHub-connected deployments, `netlify.toml` runs `bash tools/netlify-build.sh` and publishes `build/web`. Leave the base directory at the repository root and use `main` as the production branch. The script installs the verified Flutter 3.44.4 revision from the official Flutter repository and builds the release web app with the public Supabase configuration. No SMTP credentials are needed for the build. The first build downloads the Flutter tools and may take several minutes.

For a manual upload, build locally and deploy the **contents of `build/web`**, rather than the Flutter source folder. `netlify.toml` supplies the publish directory and SPA fallback. `_redirects` and `_headers` are also included in the web output for manual uploads.

The Netlify upload bundle is `dist/SolarCare-web-netlify.zip`. Unzip it, then upload the folder that contains `index.html` to your Netlify project. No secret server keys are included.

The public website is https://servicefacilities.netlify.app/. Supabase's Site URL and exact production redirect URL are configured to this address. GitHub pushes to `main` trigger Netlify builds.

After Netlify assigns the public URL, set Supabase Authentication → URL Configuration → Site URL to that address. Hosting does not provide SMTP: configure an email sender separately before public signups. For a small pilot, an existing Gmail account can use SMTP with a Google app password if eligible and 2-Step Verification is enabled. Enter that credential directly in Supabase settings, not in source code or chat.

## Customer login and separate worker app

The customer app at https://servicefacilities.netlify.app/ opens on sign-in for signed-out users. New customers choose Create an account, provide their name, email and password, confirm their email, then sign in. A valid saved session keeps the user signed in; signing out removes protected screens. The customer account menu shows the signed-in account and the admin dashboard for authorized administrators.

SolarServe Pro is a separate Flutter application in `worker_app/`, with its own Android/iOS identifiers and independently stored sessions. Its web entry is https://servicefacilities.netlify.app/worker/. Workers register and confirm their email, then sign in to complete a professional application. Only the admin can approve access to jobs; pending, rejected and suspended applicants see their status. Approval status refreshes automatically or through Refresh. Worker signup never grants an admin role or verification.

From the repository root, build the customer app normally. From `worker_app/`, run:

```powershell
flutter pub get
flutter run
flutter build apk --debug
flutter build web --release --base-href=/worker/
```

iOS source is included for both apps and targets iOS 13+. Build and sign each application on macOS with Xcode; iOS binaries have not been built on this Windows machine. Android testing packages are delivered locally as `dist/SolarCare-android-test.apk` and `dist/SolarCare-Pro-android-test.apk`.

The Netlify build script builds both web applications and places SolarServe Pro under `build/web/worker/`. A manual web upload must include that folder. Both exact production URLs are allowed in Supabase authentication redirects. The customer and worker apps share real accounts and backend records; their stored login sessions stay separate. No sample users or worker profiles are created.

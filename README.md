# SolarServe

Solar-first property maintenance for Ernakulam and Thrissur. The customer app and separate SolarServe Pro worker app share Flutter screens and a real Supabase backend. Wide customer web screens use the supplied desktop dashboard layout; phones use the supplied mobile layout. The design references guide appearance, never the sample people, ratings, bookings or earnings shown in them.

Customer website: https://servicefacilities.netlify.app/

Worker website: https://servicefacilities.netlify.app/worker/

Source: https://github.com/jj749912-glitch/Service-App

## Account and appointment flow

Email/password login and email confirmation are enabled. SMS OTP and Google login are not connected. Configure SMTP in Supabase before opening registration to the public. Never place SMTP passwords or server keys in source code. The included Supabase settings contain only a public client key.

Workers register with their qualification, confirm their email, sign in and complete the application. An application requires a real name, qualification, Indian mobile number, service city, and one or more services. Each service has its own hourly rate, experience and description. The profile and phone are saved atomically. An administrator reviews the real qualifications, identity, area and rates, then approves once; the administrator can suspend access later.

Approved workers open Home and enable **Online for nearby bookings**. They grant location permission and keep the worker app open. The server rounds discovery coordinates to three decimal places, so nearby customers see an approximate availability location. Going offline or backgrounding the app clears the point; failed cleanup expires after two minutes. Workers without current shared availability are not presented as available nearby.

Customer booking:

1. Choose **Book a Service** or **Choose Location & Find Workers** in Explore.
2. Enter the full service address and select its location using GPS or by tapping the map. Ernakulam is initially selected; Thrissur is also supported.
3. Select one or more services. All six categories are available; tap a selected card again to remove it.
4. Choose **One worker for all services** or **Choose a worker for each service**. The first choice lists workers offering every selected service. For separate workers, select each service chip and assign its worker. Compare real approved, online workers within 50 km of the pin. Cards list all their actual services and rates; profiles show submitted experience, qualification and reviews.
5. Enter a future date, a custom start time in `HH:mm` format and 15–720 minutes for each service. A worker's combined visit is limited to 720 minutes. Services assigned to the same worker form one appointment; different workers start at the selected time and receive independent appointments. Confirm and send the requests.
6. The assigned worker sees the request under **Jobs → New** and accepts or declines it. Declines are stored and shown as Cancelled.
7. Acceptance produces a saved customer notification and shows **Confirmed** under **My Jobs → Scheduled**. Requested appointments remain Requested until accepted.
8. On the appointment day, open **View Details → Show Worker Phone** to view/call the assigned worker. The server restricts access to that customer and that calendar day in India, for accepted/completed appointments. Numbers are not in the public directory.
9. The worker starts the journey, marks arrival, starts the job and submits completion with actual work notes. The customer sees saved milestones and can submit one review after completion. Actual reviews determine ratings and review counts.

The server calculates each service's price as `ceil(hourly_rate × duration_minutes / 60)`, sums the service lines and derives each worker's end time. A multi-worker request saves atomically; if any appointment fails, the entire request rolls back. Retrying an unchanged request returns its saved appointments without duplicates. It rejects unsupported/duplicate services, unapproved workers, invalid times and overlapping active bookings. Clients cannot alter saved service lines, price/address/customer or forge someone else's job transitions.

## Live tracking, messages and pilot limits

Precise tracking requires an **accepted** booking and opens **20 minutes before its start**. The worker explicitly enables **Share location for this visit** and keeps the job details screen and app open. GPS is uploaded every 10 seconds while sharing and read by the assigned customer every five seconds. The server checks ownership, approval, booking status and time on every read/write. Points older than two minutes are hidden. Tracking stops at completion/cancellation or the scheduled end, or when sharing is disabled. This release does not track in the background. No simulated position, route, speed, travel time or arrival estimate is shown.

Confirmed/completed booking participants can send real text messages under Messages. Private messages are checked by booking ownership and worker approval; unrelated users cannot read/send. The latest 200 messages are loaded and refreshed while open. Support chat is not staffed or connected. Saved notifications are in-app notifications, not operating-system push, SMS or confirmation emails.

The worker dashboard shows actual assigned appointments, completed job labour estimates and review aggregates. Labour value is not a payment balance. Payments, payouts, subscriptions, insurance/training certifications, document verification automation, job photo uploads and worker/customer portrait uploads are not implemented. Missing photos use initials/icons. Never infer verification claims from the reference artwork.

No sample records are seeded. UI tests use isolated in-memory responses. Database checks use transactions that roll back every temporary account, worker, message, review, location and booking. Existing real records are preserved. A real physical-device location/login test still needs the actual customer's and approved worker's devices and accounts.

## Run both apps using terminals

Install Flutter **3.44.4** (Dart 3.12.2), Git and Android Studio/Android SDK. This workstation uses `C:\flutter\bin`; add it to PATH. Run `flutter doctor -v`. Enable USB debugging on an Android phone, approve the computer connection, then find device IDs with `flutter devices`.

Customer, terminal 1:

```powershell
Set-Location D:\Service_app\Solar-app
flutter pub get
flutter devices
flutter run -d <customer-device-id> --dart-define-from-file=supabase-config.json
```

Worker, terminal 2:

```powershell
Set-Location D:\Service_app\Solar-app\worker_app
flutter pub get
flutter run -d <worker-device-id> --dart-define-from-file=../supabase-config.json
```

Use different real customer/worker accounts. Both Android applications can coexist on the same phone, but two devices are useful for testing location sharing. Grant foreground location permission when prompted. TLS verification remains enabled.

For browsers, replace the device ID with `chrome`; for the worker web build the production base path is `/worker/`. Browsers require location permission and HTTPS (localhost is suitable for local development). If GPS is denied, customers can choose a map pin manually. Map tiles are OpenStreetMap with attribution; choose an appropriate commercial/managed tile service before a large launch.

## Build and install Android APKs

Customer, from the repository root:

```powershell
flutter build apk --debug --dart-define-from-file=supabase-config.json
New-Item -ItemType Directory -Force dist
Copy-Item build\app\outputs\flutter-apk\app-debug.apk dist\SolarServe-android-test.apk
```

Worker:

```powershell
Set-Location worker_app
flutter build apk --debug --dart-define-from-file=../supabase-config.json
Copy-Item build\app\outputs\flutter-apk\app-debug.apk ..\dist\SolarServe-Pro-android-test.apk
Set-Location ..
```

Testing APK locations:

- `D:\Service_app\Solar-app\dist\SolarServe-android-test.apk`
- `D:\Service_app\Solar-app\dist\SolarServe-Pro-android-test.apk`

Copy APKs to the phone and open them; allow installation from the file app when prompted. Debug APKs are for testing. For public Android distribution, configure your protected release keystore, then build `flutter build apk --release` or `flutter build appbundle --release` in each app directory. Release outputs are under that app's `build/app/outputs/`. Never commit keystores or passwords.

## iOS

Both apps include iOS source and foreground location descriptions. CocoaPods configuration disables the unused always-location permission requirement. Build/sign each app on a Mac with Xcode and CocoaPods; iOS binaries cannot be built on this Windows workstation.

```sh
flutter pub get
flutter run -d <iphone-id> --dart-define-from-file=supabase-config.json
flutter build ios --no-codesign --dart-define-from-file=supabase-config.json
cd worker_app
flutter pub get
flutter build ios --no-codesign --dart-define-from-file=../supabase-config.json
```

Open each app's `ios/Runner.xcworkspace`, choose the Apple developer team and configure signing for installable distribution. Physical iPhone behavior remains to be verified. Foreground permission setup follows the [Geolocator documentation](https://pub.dev/packages/geolocator/versions/14.1.1).

## Verification and backend history

Both mobile apps share the checked color palette: dark blue action buttons, dark secondary text, readable selected chips, clear field borders, dark error/success text, and photo scrims behind white captions. Worker summary tiles use darker teal. `test/mobile_contrast_test.dart` verifies at least 4.5:1 for active text and 3:1 for field borders/checkmarks, including the brightest possible photo background. These are measured palette checks and rendered screen reviews, not a full accessibility certification or a physical-device sunlight test.

```powershell
flutter analyze
flutter test
Set-Location worker_app
flutter analyze
Set-Location ..
flutter build web --release --no-wasm-dry-run --dart-define-from-file=supabase-config.json
```

The connected Supabase project is `usgdrzubndfvfarkklok`. Applied migration history is in its dashboard. `backend/` holds reference upgrade SQL; **do not rerun upgrades on the initialized project**. `backend/multi-service-scheduling-tracking.sql` covers multi-service profiles, custom durations, saved notifications, availability, private tracking/contacts, job milestones and booking messages. The subsequent `backend/customer-multi-service-bookings.sql` adds customer multi-service appointments, grouped worker requests, server-priced service lines and safe retries.

Verification scripts must be executed in full, including their final `ROLLBACK`:

- `backend/customer-multi-service-bookings-check.sql`: combined/separate workers, line prices/durations, atomic failures, retries, independent decisions and access isolation.
- `backend/multi-service-workflow-check.sql`: application atomicity, service rates/duration, overlap, decisions, notification ownership, tracking window, private contacts, milestones, messages and completed-only reviews.
- `backend/booking-workflow-check.sql`: base customer/worker request synchronization and role isolation.
- `backend/admin-access-check.sql`: administrator access, approval, profile editing, suspension, restoration and audit.
- `backend/admin-account-management-check.sql`: admin-only delegation, active/confirmed account checks, session validation and audit; all fixtures roll back.

Private admin tables deliberately have no direct client policies; protected server functions manage them. Leaked-password protection is disabled in the current project and can be enabled if the account plan supports it. See [Supabase password security](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).

## Upload source and publish through Netlify

From the repository root:

```powershell
git status
git diff
flutter analyze
flutter test
git add README.md lib test backend pubspec.yaml pubspec.lock android ios windows tools worker_app
git diff --cached --stat
git commit -m "Update SolarServe booking and worker workflows"
git push origin main
```

Review intended files before committing. Generated build output, `dist/`, local SDK paths and secrets are excluded. Never force-push shared work.

Netlify is connected to the repository's **main** branch. Base directory: repository root. Build: `bash tools/netlify-build.sh`. Publish directory: `build/web`. The script installs the pinned official Flutter revision, builds the customer web app, builds SolarServe Pro with `--base-href=/worker/`, and places the latter under `build/web/worker/`. A GitHub push triggers deployment. Confirm the newest commit is **Published**, then refresh both production URLs.

For a manual upload, build both apps locally, copy `worker_app/build/web` into `build/web/worker`, and upload the folder containing the root `index.html`. Keep `_redirects` and `_headers`. Uploading Flutter source alone does not update the hosted site.

## Pilot costs and administrator setup

The testing Supabase project was created at the authorized $0/month quote. This implementation adds no paid SMS, maps, payment or background-tracking integration. Monitor database, bandwidth and realtime usage in Supabase; free-tier quotas are not a capacity guarantee. See [current Supabase pricing](https://supabase.com/pricing). Netlify and app-store accounts have their own terms.

**Admin Dashboard** appears in the customer desktop sidebar and Profile controls only when the signed-in account has administrator permission. Ordinary customers and workers have no admin menu entry. Direct navigation to `https://servicefacilities.netlify.app/#/admin` still requires a valid administrator session; every administrative server operation also checks permission. Membership is held in `private.app_admins`, never user-editable metadata.

To create another administrator, have that person register normally and confirm their email. An existing administrator signs in, opens **Admin Dashboard → Users**, finds the correct account, and selects **Make Administrator**. Verify the account holder, confirm the three permission statements, enter a reason and submit. The new administrator can then access the dashboard and grant access to other administrators. Unconfirmed, deleted and banned accounts cannot be promoted; every successful grant records the acting administrator and reason. Customers and workers cannot promote themselves. `backend/admin-account-management.sql` contains this applied upgrade. The initial administrator remains owner-provisioned; public signup never grants admin permission.

Worker approval should follow real identity/qualification checks, not an unchecked design badge. Suspending a worker blocks job access and removes their discovery visibility, including with existing client tokens.

SMTP and email redirects are configured in Supabase. Allow both exact customer and worker production URLs. Hosting does not provide SMTP. `BREVO_SETUP.md` contains the earlier provider guide; use the sender provider chosen for this project and enter credentials only in the Supabase dashboard.

The supplied original app icon is preserved in `assets/branding/app-icon.png`; generated artwork is documented under `assets/mobile/ASSET_PROMPTS.md`. Poppins includes its license in `assets/fonts/OFL.txt`.

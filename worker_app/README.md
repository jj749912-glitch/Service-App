# SolarCare Pro

Separate Android, iOS and web application for SolarCare professionals.

Run `flutter pub get` and `flutter run` in this directory. The shared application
code and real Supabase connection are supplied by the parent `solarcare` package.
Signup requires email confirmation; workers submit a profile application and
wait for administrator approval before accessing jobs. Sessions are stored
separately from the customer app. No sample records are created.

Build web with `flutter build web --release --base-href=/worker/`.
The root Netlify build script deploys it at `/worker/` alongside the customer app.
Build Android with `flutter build apk --debug`. iOS needs macOS, Xcode and signing.
See the root README for deployment, authentication and approval details.
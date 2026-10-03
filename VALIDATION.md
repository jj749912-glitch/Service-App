# Validation — 3 October 2026

- Admin update: Flutter analysis passed; all 3 existing tests and 4 admin tests passed. Admin tests cover fail-closed access, mobile dashboard layout, immediate removal of displayed admin data after revocation, required approval checks/reason, and suspended-worker status.
- Database admin regression transaction passed: ordinary and anonymous accounts cannot call admin operations or grant themselves membership; user metadata cannot authorize admin access; workers cannot self-verify; admin profile editing updates future booking pricing; approval, suspension, restoration, cancellation and audit recording work; revoked admin membership takes effect with the same claims. Every fixture and audit event was rolled back. Remaining data: 1 real user/admin, 0 professionals, 0 bookings, 0 admin audit events.
- Security advisor notices after admin changes: private tables intentionally have RLS enabled with no client policies and no direct client grants (default deny); existing Auth leaked-password protection warning remains. See https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection. No secret keys are used by the client.
- Web production URL: https://servicefacilities.netlify.app/. Authentication confirmation redirects use this URL. Admin changes use the shared Flutter screens for Android/iOS/web; this update has not been device-tested on Android or built on iOS.

- Supplied logo update: original artwork preserved byte-for-byte; app header, Android/iOS/web/Windows icon files replaced. iOS icon dimensions and opaque format verified. Flutter analysis and all 3 existing widget tests passed. Updated web and Android debug builds succeeded; browser preview visibly shows the new logo. iOS compilation still requires macOS/Xcode.

- Flutter analysis: no issues.
- Widget tests: all 3 passed (Ernakulam default, empty real-data directory, legacy local bookings ignored, missing-backend setup guidance, mobile layout).
- Connected web build: succeeded; browser verified an empty Ernakulam directory and exactly Ernakulam/Thrissur in the location selector.
- Earlier baseline Supabase security advisors: no findings before the admin migration; current notices are described above.
- Database verification: account-backed worker application, server-derived price, completed-booking review permission, calculated review rating and Ernakulam default passed in a rolled-back transaction.
- Earlier database checks verified booking overlap exclusion, cross-customer privacy, request cancellation, self-verification rejection and worker acceptance.
- Database counts after removal and verification: 0 professionals, 0 reviews, 0 bookings. No verification data was persisted.
- Android build configuration disables Kotlin incremental compilation because the workspace is on D: and the installed Flutter package cache is on C:.
- iOS deployment target and installed native plugin minimums match at iOS 13. An iOS build and device test require macOS/Xcode and have not been performed here.
- Android normal debug APK: build succeeded; delivered in `dist/SolarCare-android-test.apk`. Startup logs confirmed Flutter engine and Supabase initialization. Emulator integration and normal debugger attachment both failed with a local WebSocket service connection closing, so device screen checks are unverified.
- Public email signup requires a configured SMTP provider; Supabase's default sender is limited to organization team addresses.

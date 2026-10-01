#!/usr/bin/env bash
set -euo pipefail

solarcare_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$solarcare_root"

# Match the Flutter SDK used for the verified local builds.
solarcare_flutter_version="3.44.4"
solarcare_flutter_revision="ad70ec4617166f1c38e5d2bfd388af71fda14f06"
solarcare_flutter_sdk="$solarcare_root/.netlify/flutter-sdk"

if [[ ! -x "$solarcare_flutter_sdk/bin/flutter" ]]; then
  mkdir -p "$(dirname "$solarcare_flutter_sdk")"
  git clone --depth 1 --branch "$solarcare_flutter_version" \
    https://github.com/flutter/flutter.git "$solarcare_flutter_sdk"
fi

if [[ "$(git -C "$solarcare_flutter_sdk" rev-parse HEAD)" != "$solarcare_flutter_revision" ]]; then
  echo "Flutter SDK revision does not match the verified build version." >&2
  exit 1
fi

"$solarcare_flutter_sdk/bin/flutter" config --enable-web
"$solarcare_flutter_sdk/bin/flutter" pub get
"$solarcare_flutter_sdk/bin/flutter" build web --release --no-wasm-dry-run \
  --dart-define-from-file=supabase-config.json

test -f build/web/index.html
test -f build/web/assets/assets/branding/logo.png

#!/usr/bin/env bash
# Build ChinGo and put it on TestFlight.
#
#   ./scripts/testflight.sh            archive + export a signed .ipa
#   ./scripts/testflight.sh --upload   also upload it to App Store Connect
#
# The build number is bumped automatically. App Store Connect rejects a build whose number it
# has already seen, and doing it by hand is how you lose ten minutes to a duplicate-build
# error after a five-minute archive.
#
# Uploading needs an App Store Connect API key. Create one at
# App Store Connect > Users and Access > Integrations > App Store Connect API, download the
# .p8 ONCE, then put these in your shell profile:
#
#   export ASC_KEY_ID=XXXXXXXXXX
#   export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
#   export ASC_KEY_PATH=~/private_keys/AuthKey_XXXXXXXXXX.p8
#
# Nothing here reads, prints, or stores the key itself.
set -euo pipefail

cd "$(dirname "$0")/.."
BUILD_DIR="build/testflight"
ARCHIVE="$BUILD_DIR/ChinGo.xcarchive"
EXPORT="$BUILD_DIR/export"

mkdir -p "$BUILD_DIR"
rm -rf "$ARCHIVE" "$EXPORT"

# --- bump the build number -------------------------------------------------
current=$(grep -E 'CURRENT_PROJECT_VERSION:' ios/project.yml | head -1 | sed -E 's/[^0-9]//g')
next=$((current + 1))
sed -i '' -E "s/CURRENT_PROJECT_VERSION: \"?${current}\"?/CURRENT_PROJECT_VERSION: \"${next}\"/" ios/project.yml
version=$(grep -E 'MARKETING_VERSION:' ios/project.yml | head -1 | sed -E 's/.*"(.*)".*/\1/')
echo "Building ${version} (${next})"

cd ios
xcodegen generate --spec project.yml >/dev/null

# --- archive ---------------------------------------------------------------
xcodebuild -project ChinGo.xcodeproj -scheme ChinGo -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "../$ARCHIVE" \
  -allowProvisioningUpdates archive | tail -3

# --- export ----------------------------------------------------------------
cat > "../$BUILD_DIR/ExportOptions.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key><string>app-store-connect</string>
    <key>teamID</key><string>R43H5332KH</string>
    <key>uploadSymbols</key><true/>
    <key>signingStyle</key><string>automatic</string>
    <key>destination</key><string>export</string>
</dict>
</plist>
PLIST

xcodebuild -exportArchive -archivePath "../$ARCHIVE" \
  -exportOptionsPlist "../$BUILD_DIR/ExportOptions.plist" \
  -exportPath "../$EXPORT" -allowProvisioningUpdates | tail -2

cd ..
IPA="$EXPORT/ChinGo.ipa"
echo
echo "Built: $IPA"

# --- upload ----------------------------------------------------------------
if [[ "${1:-}" == "--upload" ]]; then
  if [[ -z "${ASC_KEY_ID:-}" || -z "${ASC_ISSUER_ID:-}" ]]; then
    echo "Set ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_PATH first (see the top of this file)." >&2
    exit 1
  fi
  xcrun altool --upload-app --type ios --file "$IPA" \
    --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
  echo
  echo "Uploaded. It takes 5-15 minutes to finish processing before it appears in TestFlight."
else
  echo
  echo "To upload, either:"
  echo "  ./scripts/testflight.sh --upload        (needs the API key env vars)"
  echo "  or open Transporter.app and drag in the .ipa"
fi

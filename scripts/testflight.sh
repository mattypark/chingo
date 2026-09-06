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
# UPLOADING needs credentials, and there are two ways. Pick one, once.
#
# A) App-specific password — quickest, no downloads, no API key.
#    1. appleid.apple.com > Sign-In and Security > App-Specific Passwords > +
#    2. Store it in your keychain (you type the password, it is never written to a file):
#         xcrun altool --store-password-in-keychain-item --item AC_PASSWORD \
#           -u you@example.com -p <the-app-specific-password>
#
#       The `--item` flag is REQUIRED and altool's own usage text omits it. Without it you
#       get "Expected item argument is missing, --item. (29)", which reads like you left
#       out the name you clearly just typed. Verified against altool 26.40.1.
#    3. export ASC_APPLE_ID=you@example.com
#
# B) App Store Connect API key — better for CI, one-time download of a .p8.
#    App Store Connect > Users and Access > Integrations > App Store Connect API > +
#    (role: App Manager). The .p8 can only be downloaded ONCE.
#      export ASC_KEY_ID=XXXXXXXXXX
#      export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
#
# Nothing here ever reads, prints, or stores a credential — the keychain and the environment
# hold them, this script only names them.
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
  # Written by scripts/asc-setup.sh, so a single API key covers uploading and the MCP and
  # there is nothing to add to your shell profile.
  if [[ -f "$HOME/.config/asc-mcp/asc.env" ]]; then
    # shellcheck disable=SC1091
    source "$HOME/.config/asc-mcp/asc.env"
  fi

  if [[ -n "${ASC_APPLE_ID:-}" ]]; then
    echo "Uploading as $ASC_APPLE_ID..."
    xcrun altool --upload-app --type ios --file "$IPA" \
      -u "$ASC_APPLE_ID" -p "@keychain:AC_PASSWORD"
  elif [[ -n "${ASC_KEY_ID:-}" && -n "${ASC_ISSUER_ID:-}" ]]; then
    echo "Uploading with API key $ASC_KEY_ID..."
    xcrun altool --upload-app --type ios --file "$IPA" \
      --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
  else
    echo "No upload credentials set. See the top of this file — option A takes a minute." >&2
    echo "Or open Transporter.app and drag in: $IPA" >&2
    exit 1
  fi
  echo
  echo "Uploaded. Processing takes 5-15 minutes; the build is genuinely not in TestFlight"
  echo "until that finishes. You will get an email either way."
else
  echo
  echo "To upload:"
  echo "  ./scripts/testflight.sh --upload"
  echo "  or open Transporter.app and drag in the .ipa above"
fi

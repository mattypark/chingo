#!/usr/bin/env bash
# Regenerate the Xcode project and resolve packages.
#
# Run this after pulling, after any change to ios/project.yml, and any time Xcode claims
# "Missing package product". The .xcodeproj is generated from project.yml and is gitignored,
# so Xcode's cached copy goes stale whenever a dependency is added -- reopening the project
# after this script is what fixes it, not a clean build.
set -euo pipefail
cd "$(dirname "$0")/../ios"

xcodegen generate --spec project.yml
xcodebuild -project ChinGo.xcodeproj -scheme ChinGo -resolvePackageDependencies

echo
echo "Done. If Xcode is open, close the project and reopen it:"
echo "  open $(pwd)/ChinGo.xcodeproj"

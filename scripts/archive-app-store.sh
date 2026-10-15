#!/usr/bin/env bash
# Archive Stiki for App Store Connect. Requires macOS + Xcode 26 + a team ID.
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script must run on a Mac with Xcode 26." >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEAM_ID="${TEAM_ID:-}"
if [[ -z "$TEAM_ID" ]]; then
  echo "Set TEAM_ID to your 10-character Apple Developer Team ID." >&2
  exit 1
fi

EXPORT_OPTS="$ROOT/Config/exportOptions.plist"
WORK="$ROOT/build/appstore"
ARCHIVE="$WORK/Stiki.xcarchive"
EXPORT_DIR="$WORK/export"

mkdir -p "$WORK"
/usr/libexec/PlistBuddy -c "Set :teamID $TEAM_ID" "$EXPORT_OPTS"

cd "$ROOT"
command -v xcodegen >/dev/null && xcodegen generate

xcodebuild \
  -scheme Stiki \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  MARKETING_VERSION="${MARKETING_VERSION:-1.0}" \
  CURRENT_PROJECT_VERSION="${CURRENT_PROJECT_VERSION:-1}" \
  archive

xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTS"

echo "IPA: $EXPORT_DIR/Stiki.ipa"
echo "Upload with Transporter, or:"
echo "  xcrun altool --upload-app --type ios --file \"$EXPORT_DIR/Stiki.ipa\" --apiKey \$APP_STORE_API_KEY --apiIssuer \$APP_STORE_ISSUER_ID"
echo "altool / Transporter were not run from this Linux environment."

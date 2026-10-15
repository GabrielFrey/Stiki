#!/usr/bin/env bash
# Capture App Store screenshots with XCUITest + simctl. Requires macOS + Xcode 26.
# Does not use fastlane.
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script must run on a Mac with Xcode 26 and Simulator." >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${SCREENSHOT_OUT:-$ROOT/docs/screenshots}"
IPHONE_DEST="${IPHONE_DEST:-platform=iOS Simulator,name=iPhone 17 Pro}"
IPAD_DEST="${IPAD_DEST:-platform=iOS Simulator,name=iPad Pro 13-inch (M5)}"

# Required ASC sizes as of the Screenshot specifications page fetched 2026-10-15:
# iPhone Dynamic Island (medium): 1179x2556 or 1206x2622
# iPad 13-inch: 2064x2752 or 2048x2732
IPHONE_W="${IPHONE_W:-1179}"
IPHONE_H="${IPHONE_H:-2556}"
IPAD_W="${IPAD_W:-2064}"
IPAD_H="${IPAD_H:-2752}"

cd "$ROOT"
command -v xcodegen >/dev/null && xcodegen generate

capture() {
  local dest="$1"
  local folder="$2"
  local width="$3"
  local height="$4"
  mkdir -p "$folder"
  echo "Capturing $dest → $folder"
  local result="$folder/capture.xcresult"
  rm -rf "$result"
  # TEST_RUNNER_* is forwarded into the XCTest process. Writing a host path
  # from the simulator is best-effort; attachments in the result bundle are
  # the reliable copy.
  TEST_RUNNER_SCREENSHOT_DIR="$folder" xcodebuild test \
    -scheme Stiki \
    -destination "$dest" \
    -only-testing:StikiUITests/ScreenshotCaptureTests \
    -configuration Debug \
    -resultBundlePath "$result"
  if xcrun xcresulttool export attachments --path "$result" --output-path "$folder" 2>/dev/null; then
    echo "Exported xcresult attachments to $folder"
  else
    echo "xcresulttool attachment export failed or is unavailable. Open $result in Xcode and save the screenshot attachments."
  fi
  if command -v sips >/dev/null; then
    for png in "$folder"/*.png; do
      [[ -f "$png" ]] || continue
      sips -s format png --deleteColorManagementProperties "$png" >/dev/null
      # Flatten / drop alpha: ASC rejects screenshots with an alpha channel.
      sips -s format jpeg "$png" --out "${png%.png}.jpg" >/dev/null
      sips -s format png "${png%.png}.jpg" --out "$png" >/dev/null
      rm -f "${png%.png}.jpg"
      sips -z "$height" "$width" "$png" >/dev/null || true
    done
  else
    echo "sips not found; PNGs are simulator-native size. Resize before upload."
  fi
}

capture "$IPHONE_DEST" "$OUT/iphone" "$IPHONE_W" "$IPHONE_H"
capture "$IPAD_DEST" "$OUT/ipad" "$IPAD_W" "$IPAD_H"

echo "Wrote $OUT. Review Guideline 2.3.3 (app in use, not splash) before upload."
echo "iMessage wells: capture the Messages extension separately if ASC still shows them."

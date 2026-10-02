#!/bin/bash
# WantWise — one-command Simulator build/test for a (rented) Mac. [MAC REQUIRED]
#
#   cd wantwise/apps/ios
#   ./scripts/mac-build.sh            # core tests + generate + build
#   ./scripts/mac-build.sh test       # ...then unit tests
#   ./scripts/mac-build.sh uitest     # ...then unit + UI tests
#   ./scripts/mac-build.sh run        # ...build, install and launch in the Simulator with sample data
#
# No Apple Developer account or Team ID is needed: Simulator builds are signed "to run locally" (D-026).
# Logs go to apps/ios/build-logs/ (git-ignored). A short error summary is printed at the end and saved to
# build-logs/errors.txt so it can be pasted straight to Claude.
#
# Compatible with macOS's default bash 3.2.

set -u
cd "$(dirname "$0")/.."
MODE="${1:-build}"
LOGS="build-logs"
DERIVED="build/DerivedData"
mkdir -p "$LOGS"
: > "$LOGS/errors.txt"

step() { printf '\n\033[1;33m▶ %s\033[0m\n' "$1"; }
fail() {
  printf '\n\033[1;31m✖ %s\033[0m\n' "$1"
  summarize "$2"
  exit 1
}
summarize() {
  local log="$1"
  [ -f "$log" ] || return
  # Unique compiler/linker errors, with file:line, most useful first.
  grep -E "(error|fatal error):" "$log" | sed -E 's#^.*/apps/ios/##' | sort -u | head -60 > "$LOGS/errors.txt"
  grep -E "^\s*(✘|Test Case .* failed|.*: error: -\[)" "$log" | sort -u | head -40 >> "$LOGS/errors.txt"
  if [ -s "$LOGS/errors.txt" ]; then
    printf '\n----- %s (paste this to Claude) -----\n' "$LOGS/errors.txt"
    cat "$LOGS/errors.txt"
    printf -- '-----------------------------------------------\n'
  fi
}

step "Tools"
xcodebuild -version || fail "Xcode is not installed or not selected (sudo xcode-select -s /Applications/Xcode.app)" ""
if ! command -v xcodegen >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    brew install xcodegen || fail "brew install xcodegen failed" ""
  else
    fail "XcodeGen missing and Homebrew not available. See docs/CLOUD_MAC_SESSION.md → Install XcodeGen." ""
  fi
fi
xcodegen --version

step "WantWiseCore package tests (also verified on Linux)"
(cd WantWiseCore && swift test 2>&1) | tee "$LOGS/core-tests.log" | tail -3
[ "${PIPESTATUS[0]}" -eq 0 ] || fail "WantWiseCore tests failed" "$LOGS/core-tests.log"

step "Generate Xcode project"
xcodegen generate 2>&1 | tee "$LOGS/xcodegen.log" | tail -2
[ "${PIPESTATUS[0]}" -eq 0 ] || fail "xcodegen generate failed" "$LOGS/xcodegen.log"

step "Pick a Simulator"
# Prefer a recent standard iPhone; fall back to the first available iPhone.
DEVICE_LINE="$(xcrun simctl list devices available | grep -E '^\s+iPhone 1[5-9] \(' | head -1)"
[ -n "$DEVICE_LINE" ] || DEVICE_LINE="$(xcrun simctl list devices available | grep -E '^\s+iPhone' | head -1)"
[ -n "$DEVICE_LINE" ] || fail "No iPhone Simulator found. Xcode → Settings → Platforms → install iOS." ""
UDID="$(echo "$DEVICE_LINE" | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')"
NAME="$(echo "$DEVICE_LINE" | sed -E 's/^[[:space:]]+//; s/ \([0-9A-F-]{36}\).*//')"
echo "Using: $NAME ($UDID)"
DEST="platform=iOS Simulator,id=$UDID"

step "Build (Debug, Simulator)"
xcodebuild -project WantWise.xcodeproj -scheme WantWise -configuration Debug \
  -destination "$DEST" -derivedDataPath "$DERIVED" build > "$LOGS/build.log" 2>&1
BUILD_STATUS=$?
tail -5 "$LOGS/build.log"
[ $BUILD_STATUS -eq 0 ] || fail "Build failed (full log: $LOGS/build.log)" "$LOGS/build.log"
printf '\033[1;32m✔ Build succeeded\033[0m\n'

if [ "$MODE" = "test" ] || [ "$MODE" = "uitest" ]; then
  step "Unit tests (WantWiseTests)"
  xcodebuild -project WantWise.xcodeproj -scheme WantWise -destination "$DEST" -derivedDataPath "$DERIVED" \
    -only-testing:WantWiseTests test > "$LOGS/unit-tests.log" 2>&1
  STATUS=$?
  grep -E "Test run with|Executed|✔ Suite|✘" "$LOGS/unit-tests.log" | tail -25
  [ $STATUS -eq 0 ] || fail "Unit tests failed (full log: $LOGS/unit-tests.log)" "$LOGS/unit-tests.log"
  printf '\033[1;32m✔ Unit tests passed\033[0m\n'
fi

if [ "$MODE" = "uitest" ]; then
  step "UI tests (WantWiseUITests)"
  xcodebuild -project WantWise.xcodeproj -scheme WantWise -destination "$DEST" -derivedDataPath "$DERIVED" \
    -only-testing:WantWiseUITests test > "$LOGS/ui-tests.log" 2>&1
  STATUS=$?
  grep -E "Executed|passed|failed" "$LOGS/ui-tests.log" | tail -15
  [ $STATUS -eq 0 ] || fail "UI tests failed (full log: $LOGS/ui-tests.log)" "$LOGS/ui-tests.log"
  printf '\033[1;32m✔ UI tests passed\033[0m\n'
fi

if [ "$MODE" = "run" ]; then
  step "Install and launch with sample data"
  APP="$(find "$DERIVED/Build/Products/Debug-iphonesimulator" -maxdepth 1 -name 'WantWise.app' | head -1)"
  BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")"
  xcrun simctl boot "$UDID" 2>/dev/null || true
  open -a Simulator
  xcrun simctl install "$UDID" "$APP"
  xcrun simctl launch "$UDID" "$BUNDLE_ID" -WantWiseSampleData
  echo "Launched $BUNDLE_ID on $NAME."
fi

printf '\n\033[1;32mDone.\033[0m Logs: apps/ios/%s/\n' "$LOGS"

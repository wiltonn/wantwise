#!/bin/bash
# WantWise — Simulator build/test loop for a (rented) Mac. [MAC REQUIRED]
# Designed for fast compile → fix → rebuild cycles, by a person or by Claude Code.
#
#   apps/ios/scripts/mac-build.sh            core tests + xcodegen + unsigned Simulator build
#   apps/ios/scripts/mac-build.sh fast       xcodegen + build only (quickest loop while fixing compile errors)
#   apps/ios/scripts/mac-build.sh test       build + unit tests (WantWiseTests)
#   apps/ios/scripts/mac-build.sh uitest     build + unit tests + UI tests
#   apps/ios/scripts/mac-build.sh run        build, add sample screenshots to Photos, install, launch with sample data
#   apps/ios/scripts/mac-build.sh screens    build, then launch with sample data on small / standard / Pro Max
#                                            Simulators and save screenshots to build-logs/screens/
#
# Needs no Apple Developer account, Team ID, certificate or device (D-026). No Homebrew, no sudo.
# Outputs (git-ignored), all under apps/ios/build-logs/:
#   summary.md   environment + each step's result (read this first)
#   errors.txt   deduplicated compiler/test errors, paths relative to apps/ios
#   *.log        full logs
#
# Compatible with macOS's default bash 3.2.

set -u
[ -f "$HOME/.wantwise-env" ] && . "$HOME/.wantwise-env"
cd "$(dirname "$0")/.." || exit 1
IOS_DIR="$(pwd)"
MODE="${1:-build}"
LOGS="build-logs"
DERIVED="build/DerivedData"
mkdir -p "$LOGS"
: > "$LOGS/errors.txt"
SUMMARY="$LOGS/summary.md"
EXTRA_FLAGS=""

{
  echo "# mac-build.sh $MODE — $(date '+%Y-%m-%d %H:%M:%S')"
  echo
  echo "- macOS $(sw_vers -productVersion) ($(uname -m))"
  echo "- $(xcodebuild -version 2>/dev/null | tr '\n' ' ')"
  echo "- commit $(git log -1 --format='%h %s' 2>/dev/null)"
} > "$SUMMARY"

step()   { printf '\n\033[1;33m▶ %s\033[0m\n' "$1"; }
record() { echo "- $1" >> "$SUMMARY"; }
collect_errors() {
  [ -f "$1" ] || return
  {
    grep -E "(error|fatal error):" "$1" | sed -E "s#(/Volumes/[^/]+)?$IOS_DIR/##g" | sort -u | head -80
    grep -E "✘|Test Case .* failed|XCTAssert.*failed|failed - " "$1" | sed -E "s#(/Volumes/[^/]+)?$IOS_DIR/##g" | sort -u | head -40
  } >> "$LOGS/errors.txt"
}
fail() {
  printf '\n\033[1;31m✖ %s\033[0m\n' "$1"
  record "✖ $1"
  [ -n "${2:-}" ] && collect_errors "$2"
  if [ -s "$LOGS/errors.txt" ]; then
    echo >> "$SUMMARY"; echo "## Errors (also in errors.txt)" >> "$SUMMARY"; echo '```' >> "$SUMMARY"
    head -40 "$LOGS/errors.txt" >> "$SUMMARY"; echo '```' >> "$SUMMARY"
    printf '\n----- %s/errors.txt -----\n' "$LOGS"; head -60 "$LOGS/errors.txt"; printf -- '-------------------------\n'
  fi
  exit 1
}

# ---------------------------------------------------------------- tools
step "Tools"
xcodebuild -version >/dev/null 2>&1 || fail "xcodebuild unavailable. Run scripts/mac-bootstrap.sh first."
command -v xcodegen >/dev/null 2>&1 || fail "xcodegen not on PATH. Run scripts/mac-bootstrap.sh (installs to ~/.local/xcodegen)."
record "xcodegen $(xcodegen --version 2>/dev/null | sed 's/Version: //')"

# ---------------------------------------------------------------- core package
if [ "$MODE" != "fast" ]; then
  step "WantWiseCore package tests"
  (cd WantWiseCore && swift test) > "$LOGS/core-tests.log" 2>&1
  STATUS=$?
  grep -E "Test run with|Executed" "$LOGS/core-tests.log" | tail -2
  [ $STATUS -eq 0 ] || fail "WantWiseCore tests failed (log: $LOGS/core-tests.log)" "$LOGS/core-tests.log"
  record "✔ WantWiseCore: $(grep -E 'Test run with' "$LOGS/core-tests.log" | tail -1 | sed -E 's/.*(Test run with [0-9]+ tests in [0-9]+ suites).*/\1/')"
fi

# ---------------------------------------------------------------- project
step "Generate Xcode project"
xcodegen generate --quiet > "$LOGS/xcodegen.log" 2>&1 || fail "xcodegen generate failed (log: $LOGS/xcodegen.log)" "$LOGS/xcodegen.log"
record "✔ xcodegen generate"

# ---------------------------------------------------------------- simulators
# Prints "Name|UDID" for the first available device whose name matches the extended regex.
find_device() {
  xcrun simctl list devices available | grep -E "^[[:space:]]+($1) \(" | head -1 \
    | sed -E 's/^[[:space:]]+(.*) \(([0-9A-F-]{36})\).*/\1|\2/'
}
# Creates a device from the newest iOS runtime if a device type matching the regex exists.
create_device() {
  local type runtime
  type="$(xcrun simctl list devicetypes | grep -E "$1" | tail -1 | sed -E 's/.*\((com\.apple[^)]*)\).*/\1/')"
  runtime="$(xcrun simctl list runtimes | grep -E '^iOS ' | tail -1 | sed -E 's/.* - (com\.apple[^ ]*).*/\1/')"
  [ -n "$type" ] && [ -n "$runtime" ] || return 1
  local udid
  udid="$(xcrun simctl create "WantWise $2" "$type" "$runtime" 2>/dev/null)" || return 1
  echo "WantWise $2|$udid"
}

step "Pick a Simulator"
PRIMARY="$(find_device 'iPhone 1[5-9]|iPhone 2[0-9]')"
[ -n "$PRIMARY" ] || PRIMARY="$(find_device 'iPhone[^(]*')"
[ -n "$PRIMARY" ] || PRIMARY="$(create_device 'iPhone 1[5-9] \(|iPhone 2[0-9] \(' Standard)"
[ -n "$PRIMARY" ] || fail "No iPhone Simulator available. Xcode → Settings → Components → install an iOS runtime."
NAME="${PRIMARY%%|*}"; UDID="${PRIMARY##*|}"
echo "Using: $NAME ($UDID)"
record "Simulator: $NAME"
DEST="platform=iOS Simulator,id=$UDID"
# Booting first starts CoreSimulator; on a fresh login xcodebuild otherwise lists no Simulator destinations.
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || true

# ---------------------------------------------------------------- build
xc() { xcodebuild -project WantWise.xcodeproj -scheme WantWise -destination "$DEST" -derivedDataPath "$DERIVED" $EXTRA_FLAGS "$@"; }

step "Build (Debug, Simulator, unsigned)"
xc -configuration Debug build > "$LOGS/build.log" 2>&1
STATUS=$?
if [ $STATUS -ne 0 ] && grep -qiE "requires a development team|signing certificate|provisioning profile" "$LOGS/build.log"; then
  echo "Simulator signing complained; retrying with CODE_SIGNING_ALLOWED=NO (D-026 fallback)"
  record "! Simulator build needed CODE_SIGNING_ALLOWED=NO (record in VERIFICATION.md)"
  EXTRA_FLAGS="CODE_SIGNING_ALLOWED=NO"
  xc -configuration Debug build > "$LOGS/build.log" 2>&1
  STATUS=$?
fi
grep -E "BUILD (SUCCEEDED|FAILED)" "$LOGS/build.log" | tail -1
[ $STATUS -eq 0 ] || fail "Build failed (log: $LOGS/build.log)" "$LOGS/build.log"
WARNINGS="$(grep -cE "warning:" "$LOGS/build.log")"
record "✔ Build succeeded ($WARNINGS warning lines)"
printf '\033[1;32m✔ Build succeeded\033[0m\n'

APP_PATH="$(find "$DERIVED/Build/Products" -maxdepth 2 -name 'WantWise.app' -path '*iphonesimulator*' | head -1)"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Info.plist" 2>/dev/null)"
record "App: $APP_PATH (bundle id $BUNDLE_ID)"

# ---------------------------------------------------------------- tests
if [ "$MODE" = "test" ] || [ "$MODE" = "uitest" ]; then
  step "Unit tests (WantWiseTests)"
  xc -only-testing:WantWiseTests test > "$LOGS/unit-tests.log" 2>&1
  STATUS=$?
  grep -E "Test run with|✘|Executed" "$LOGS/unit-tests.log" | tail -20
  [ $STATUS -eq 0 ] || fail "Unit tests failed (log: $LOGS/unit-tests.log)" "$LOGS/unit-tests.log"
  record "✔ Unit tests: $(grep -E 'Test run with' "$LOGS/unit-tests.log" | tail -1 | sed -E 's/.*(Test run with [^.]*).*/\1/')"
fi

if [ "$MODE" = "uitest" ]; then
  step "UI tests (WantWiseUITests)"
  xc -only-testing:WantWiseUITests test > "$LOGS/ui-tests.log" 2>&1
  STATUS=$?
  grep -E "Test Case .*(passed|failed)|Executed" "$LOGS/ui-tests.log" | tail -15
  [ $STATUS -eq 0 ] || fail "UI tests failed (log: $LOGS/ui-tests.log)" "$LOGS/ui-tests.log"
  record "✔ UI tests: $(grep -E 'Executed' "$LOGS/ui-tests.log" | tail -1 | sed -E 's/^[[:space:]]+//')"
fi

# ---------------------------------------------------------------- run / screens
launch_on() { # udid label
  xcrun simctl boot "$1" 2>/dev/null || true
  xcrun simctl bootstatus "$1" -b >/dev/null 2>&1 || true
  # Sample screenshots in Photos make "Add a screenshot or photo" testable.
  for img in WantWise/DebugSupport/SampleImages/debug-sample-*.png; do xcrun simctl addmedia "$1" "$img" 2>/dev/null; done
  xcrun simctl install "$1" "$APP_PATH" || return 1
  xcrun simctl terminate "$1" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch "$1" "$BUNDLE_ID" -WantWiseResetData -WantWiseSampleData -WantWiseNoReminders >/dev/null || return 1
}

if [ "$MODE" = "run" ]; then
  step "Install and launch with sample data"
  open -a Simulator 2>/dev/null || true
  launch_on "$UDID" || fail "Could not install/launch on $NAME"
  record "✔ Launched on $NAME with sample data (sample screenshots added to Photos)"
  echo "Launched $BUNDLE_ID on $NAME. Relaunch without arguments for the real flow:"
  echo "  xcrun simctl launch $UDID $BUNDLE_ID"
fi

if [ "$MODE" = "screens" ]; then
  step "Screenshots on three sizes"
  mkdir -p "$LOGS/screens"
  SMALL="$(find_device 'iPhone SE[^(]*|iPhone 1[0-9]e|iPhone 1[0-9] mini')"
  [ -n "$SMALL" ] || SMALL="$(create_device 'iPhone SE|iPhone 1[0-9]e' Small)"
  LARGE="$(find_device 'iPhone 1[5-9] Pro Max|iPhone 2[0-9] Pro Max')"
  [ -n "$LARGE" ] || LARGE="$(create_device 'Pro Max' ProMax)"
  for entry in "small|$SMALL" "standard|$PRIMARY" "promax|$LARGE"; do
    label="${entry%%|*}"; rest="${entry#*|}"
    [ -n "$rest" ] || { record "! no $label Simulator available"; continue; }
    dev_name="${rest%%|*}"; dev_udid="${rest##*|}"
    echo "• $label: $dev_name"
    if launch_on "$dev_udid"; then
      sleep 6
      xcrun simctl io "$dev_udid" screenshot "$LOGS/screens/$label-home.png" >/dev/null 2>&1 \
        && record "✔ screenshot $label ($dev_name): $LOGS/screens/$label-home.png" \
        || record "! screenshot failed on $dev_name"
    else
      record "! could not launch on $dev_name"
    fi
  done
fi

record "Done"
printf '\n\033[1;32mDone.\033[0m Summary: apps/ios/%s\n' "$SUMMARY"

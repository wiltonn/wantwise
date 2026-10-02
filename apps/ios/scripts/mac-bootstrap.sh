#!/bin/bash
# WantWise — first-run bootstrap for a fresh (rented) Mac. [MAC REQUIRED]
#
# Paste into Terminal (no admin, no Homebrew, no Apple account needed):
#
#   curl -fsSL https://raw.githubusercontent.com/wiltonn/wantwise/main/apps/ios/scripts/mac-bootstrap.sh -o /tmp/ww-bootstrap.sh && bash /tmp/ww-bootstrap.sh
#
# What it does (each step is safe to re-run):
#   1. checks macOS, Xcode, license/first-launch state, iOS Simulator runtime, Git
#   2. selects Xcode for this user via DEVELOPER_DIR if xcode-select points elsewhere (no sudo)
#   3. clones (or updates) ~/wantwise
#   4. installs XcodeGen 2.46.0 into ~/.local/xcodegen (prebuilt; falls back to building from source)
#   5. writes ~/.wantwise-env (PATH + DEVELOPER_DIR) and sources it from ~/.zshrc and ~/.bash_profile
#   6. runs apps/ios/scripts/mac-build.sh test: core tests → xcodegen → unsigned Simulator build → unit tests
#   7. writes apps/ios/build-logs/bootstrap-summary.md for Claude Code
#
# Compatible with macOS's default bash 3.2.

set -u
REPO_URL="${WANTWISE_REPO_URL:-https://github.com/wiltonn/wantwise.git}"
REPO_DIR="${WANTWISE_DIR:-$HOME/wantwise}"
XCODEGEN_VERSION="2.46.0"
XCODEGEN_HOME="$HOME/.local/xcodegen"
ENV_FILE="$HOME/.wantwise-env"
SUMMARY_LINES=""
BLOCKERS=""

say()   { printf '\n\033[1;33m▶ %s\033[0m\n' "$1"; }
ok()    { printf '  \033[32m✔\033[0m %s\n' "$1"; SUMMARY_LINES="$SUMMARY_LINES
- ✔ $1"; }
warn()  { printf '  \033[33m!\033[0m %s\n' "$1"; SUMMARY_LINES="$SUMMARY_LINES
- ! $1"; }
block() { printf '  \033[31m✖ %s\033[0m\n' "$1"; BLOCKERS="$BLOCKERS
- $1"; }

finish() {
  local status="$1"
  mkdir -p "$REPO_DIR/apps/ios/build-logs" 2>/dev/null
  local out="$REPO_DIR/apps/ios/build-logs/bootstrap-summary.md"
  if [ -d "$REPO_DIR/apps/ios" ]; then
    {
      echo "# Bootstrap summary ($(date '+%Y-%m-%d %H:%M'))"
      echo
      echo "Result: $status"
      echo "$SUMMARY_LINES"
      if [ -n "$BLOCKERS" ]; then echo; echo "## Blockers"; echo "$BLOCKERS"; fi
      echo
      echo "Logs: apps/ios/build-logs/ (errors.txt has the deduplicated compiler errors)"
    } > "$out"
    printf '\nSummary written to %s\n' "$out"
  fi
  if [ -n "$BLOCKERS" ]; then
    printf '\n\033[1;31mBlockers:\033[0m%s\n' "$BLOCKERS"
  fi
  printf '\nNext: docs/CLOUD_MAC_SESSION.md §4 (start Claude Code).\n'
  printf 'In new Terminal windows the environment loads automatically; in this one run:  source ~/.wantwise-env\n'
}

# ---------------------------------------------------------------- macOS
say "macOS"
OS_VERSION="$(sw_vers -productVersion)"
OS_MAJOR="${OS_VERSION%%.*}"
ARCH="$(uname -m)"
echo "  macOS $OS_VERSION ($ARCH), free disk on home volume: $(df -h "$HOME" | awk 'NR==2 {print $4}')"
if [ "$OS_MAJOR" -ge 14 ] 2>/dev/null; then ok "macOS $OS_VERSION ($ARCH)"; else warn "macOS $OS_VERSION is old; current Xcode needs a recent macOS"; fi

# ---------------------------------------------------------------- Xcode
say "Xcode"
SELECTED="$(xcode-select -p 2>/dev/null || true)"
DEV_DIR=""
if echo "$SELECTED" | grep -q "\.app/Contents/Developer"; then
  DEV_DIR="$SELECTED"
else
  # xcode-select points at Command Line Tools (or nothing): pick the newest /Applications/Xcode*.app for this user only.
  CANDIDATE="$(ls -d /Applications/Xcode*.app 2>/dev/null | sort | tail -1)"
  if [ -n "$CANDIDATE" ]; then
    DEV_DIR="$CANDIDATE/Contents/Developer"
    export DEVELOPER_DIR="$DEV_DIR"
    warn "xcode-select points to '$SELECTED'; using DEVELOPER_DIR=$DEV_DIR for this user (no sudo needed)"
  else
    block "No Xcode found in /Applications. Install Xcode (App Store or developer.apple.com/download) or choose a provider image with Xcode preinstalled."
    finish "BLOCKED"; exit 1
  fi
fi
if ! XCODE_VERSION="$(xcodebuild -version 2>&1)"; then
  echo "$XCODE_VERSION"
  if echo "$XCODE_VERSION" | grep -qi "license"; then
    block "Xcode license not accepted. Needs admin once: sudo xcodebuild -license accept (ask the provider if you have no sudo)."
  else
    block "xcodebuild failed (see above)."
  fi
  finish "BLOCKED"; exit 1
fi
XCODE_LINE="$(echo "$XCODE_VERSION" | head -1)"
XCODE_MAJOR="$(echo "$XCODE_LINE" | sed -E 's/Xcode ([0-9]+).*/\1/')"
ok "$XCODE_LINE ($(echo "$XCODE_VERSION" | tail -1)) at $DEV_DIR"
[ "$XCODE_MAJOR" -ge 16 ] 2>/dev/null || warn "Xcode 16+ is required for the Swift Testing unit tests"

if ! xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1; then
  warn "Xcode first-launch tasks not done; trying user-level: xcodebuild -runFirstLaunch"
  if xcodebuild -runFirstLaunch >/dev/null 2>&1; then ok "first-launch tasks installed"; else
    block "Xcode first-launch tasks need admin: sudo xcodebuild -runFirstLaunch (or open Xcode.app once and accept)"; fi
fi

say "iOS Simulator runtime"
RUNTIMES="$(xcrun simctl list runtimes 2>/dev/null | grep -E '^iOS ' || true)"
if [ -z "$RUNTIMES" ]; then
  warn "No iOS Simulator runtime installed. Downloading with 'xcodebuild -downloadPlatform iOS' (several GB, 10–30 min)…"
  if xcodebuild -downloadPlatform iOS; then ok "iOS runtime downloaded"; RUNTIMES="$(xcrun simctl list runtimes | grep -E '^iOS ' || true)"; else
    block "Could not download the iOS runtime. In Xcode: Settings → Components → iOS → Get."
    finish "BLOCKED"; exit 1
  fi
fi
echo "$RUNTIMES" | sed 's/^/  /'
ok "iOS runtime(s): $(echo "$RUNTIMES" | sed -E 's/^iOS ([0-9.]+).*/\1/' | tr '\n' ' ')"

# ---------------------------------------------------------------- Git
say "Git"
if GIT_V="$(git --version 2>&1)"; then ok "$GIT_V"; else block "git not available: $GIT_V"; finish "BLOCKED"; exit 1; fi
[ -n "$(git config --global user.name 2>/dev/null)" ] || warn "git user.name not set: git config --global user.name \"Nate\""
[ -n "$(git config --global user.email 2>/dev/null)" ] || warn "git user.email not set: git config --global user.email \"you@example.com\""

say "Repository"
if [ -d "$REPO_DIR/.git" ]; then
  git -C "$REPO_DIR" pull --ff-only && ok "updated $REPO_DIR ($(git -C "$REPO_DIR" log -1 --format='%h %s'))" \
    || warn "git pull failed in $REPO_DIR (local changes?); continuing with what's there"
else
  git clone "$REPO_URL" "$REPO_DIR" && ok "cloned to $REPO_DIR ($(git -C "$REPO_DIR" log -1 --format='%h %s'))" \
    || { block "git clone $REPO_URL failed"; finish "BLOCKED"; exit 1; }
fi

# ---------------------------------------------------------------- XcodeGen
say "XcodeGen"
export PATH="$XCODEGEN_HOME/bin:$HOME/.local/bin:$PATH"
if command -v xcodegen >/dev/null 2>&1 && xcodegen --version >/dev/null 2>&1; then
  ok "xcodegen already available: $(xcodegen --version) ($(command -v xcodegen))"
else
  TMP="$(mktemp -d)"
  URL="https://github.com/yonaskolb/XcodeGen/releases/download/$XCODEGEN_VERSION/xcodegen.zip"
  if curl -fsSL "$URL" -o "$TMP/xcodegen.zip" && unzip -q "$TMP/xcodegen.zip" -d "$TMP"; then
    rm -rf "$XCODEGEN_HOME" && mkdir -p "$(dirname "$XCODEGEN_HOME")" && mv "$TMP/xcodegen" "$XCODEGEN_HOME"
    chmod +x "$XCODEGEN_HOME/bin/xcodegen"
  fi
  if "$XCODEGEN_HOME/bin/xcodegen" --version >/dev/null 2>&1; then
    ok "installed XcodeGen $XCODEGEN_VERSION (prebuilt) in $XCODEGEN_HOME"
  else
    warn "prebuilt XcodeGen didn't run; building $XCODEGEN_VERSION from source (2–5 min)"
    SRC="$HOME/.local/src/XcodeGen"
    rm -rf "$SRC" && git clone -q --depth 1 --branch "$XCODEGEN_VERSION" https://github.com/yonaskolb/XcodeGen.git "$SRC" \
      && (cd "$SRC" && swift build -c release --product xcodegen >/dev/null) \
      && mkdir -p "$XCODEGEN_HOME/bin" "$XCODEGEN_HOME/share/xcodegen" \
      && cp "$SRC/.build/release/xcodegen" "$XCODEGEN_HOME/bin/" \
      && cp -R "$SRC/SettingPresets" "$XCODEGEN_HOME/share/xcodegen/"
    if "$XCODEGEN_HOME/bin/xcodegen" --version >/dev/null 2>&1; then ok "built XcodeGen from source"; else
      block "XcodeGen unavailable. Fallback: docs/CLOUD_MAC_SESSION.md → 'If XcodeGen can't be installed'"
      finish "BLOCKED"; exit 1
    fi
  fi
  rm -rf "$TMP"
fi

# ---------------------------------------------------------------- environment file
say "Shell environment"
{
  echo "# Written by WantWise mac-bootstrap.sh"
  echo "export PATH=\"$XCODEGEN_HOME/bin:\$HOME/.local/bin:\$PATH\""
  [ -n "${DEVELOPER_DIR:-}" ] && echo "export DEVELOPER_DIR=\"$DEVELOPER_DIR\""
} > "$ENV_FILE"
for rc in "$HOME/.zshrc" "$HOME/.bash_profile"; do
  grep -q "wantwise-env" "$rc" 2>/dev/null || echo '[ -f "$HOME/.wantwise-env" ] && . "$HOME/.wantwise-env"' >> "$rc"
done
ok "wrote $ENV_FILE (loaded by ~/.zshrc and ~/.bash_profile)"

# ---------------------------------------------------------------- build + tests
say "First build and tests (apps/ios/scripts/mac-build.sh test)"
if bash "$REPO_DIR/apps/ios/scripts/mac-build.sh" test; then
  ok "core tests, project generation, unsigned Simulator build and unit tests all passed"
  finish "GREEN"
else
  warn "build or tests failed: this is expected on the first run. Errors: apps/ios/build-logs/errors.txt"
  finish "NEEDS FIXES (start Claude Code)"
fi

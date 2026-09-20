#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

# Use the installed Xcode for XCTest and native SDKs without changing xcode-select.
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

if pgrep -x TetherVoice >/dev/null; then
  echo 'Quit Tether Voice before building and installing.' >&2
  exit 1
fi

xcrun swift build -c release
TETHER_BIN_DIR="$(xcrun swift build -c release --show-bin-path)"
TETHER_APP_DIR="$PWD/.build/app/Tether Voice.app"
TETHER_INSTALL_DIR="$HOME/Applications/Tether Voice.app"
mkdir -p "$TETHER_APP_DIR/Contents/MacOS" "$TETHER_APP_DIR/Contents/Resources"
cp "$TETHER_BIN_DIR/TetherVoice" "$TETHER_APP_DIR/Contents/MacOS/TetherVoice"
cp Resources/Info.plist "$TETHER_APP_DIR/Contents/Info.plist"
python3 scripts/sign-local.py "$TETHER_APP_DIR"
if pgrep -x TetherVoice >/dev/null; then
  echo 'Tether Voice was opened during the build. Quit it, then run the build again.' >&2
  exit 1
fi
mkdir -p "$HOME/Applications"
ditto "$TETHER_APP_DIR" "$TETHER_INSTALL_DIR"
codesign --verify --strict "$TETHER_INSTALL_DIR"
printf 'Installed: %s\n' "$TETHER_INSTALL_DIR"

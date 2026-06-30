#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Ghost"
BUNDLE_ID="com.local.Ghost"
MIN_SYSTEM_VERSION="14.0"
APP_VERSION="${GHOST_VERSION:-1.0.0}"
APP_BUILD="${GHOST_BUILD:-100}"
SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-}"
SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-}"

if [[ -z "${DEVELOPER_DIR:-}" && -d "/Applications/Xcode-beta.app/Contents/Developer" ]]; then
  export DEVELOPER_DIR="/Applications/Xcode-beta.app/Contents/Developer"
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ICON_FILE="$ROOT_DIR/script/Ghost.icns"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

swift build
BUILD_BINARY="$(swift build --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

RESOURCES_DIR="$APP_CONTENTS/Resources"
mkdir -p "$RESOURCES_DIR"
if [[ -f "$ICON_FILE" ]]; then
  cp "$ICON_FILE" "$RESOURCES_DIR/Ghost.icns"
fi
BUILD_BIN_DIR="$(swift build --show-bin-path)"
find "$BUILD_BIN_DIR" -maxdepth 1 -name "*.bundle" -exec cp -R {} "$RESOURCES_DIR/" \; 2>/dev/null || true
find "$BUILD_BIN_DIR/../.." -maxdepth 4 -path "*/Ghost*Resources*" -type d 2>/dev/null | while read -r dir; do
  cp -R "$dir" "$RESOURCES_DIR/"
done || true

FRAMEWORKS_DIR="$APP_CONTENTS/Frameworks"
mkdir -p "$FRAMEWORKS_DIR"
SPARKLE_FRAMEWORK=""
if [[ -d "$BUILD_BIN_DIR/Sparkle.framework" ]]; then
  SPARKLE_FRAMEWORK="$BUILD_BIN_DIR/Sparkle.framework"
else
  SPARKLE_FRAMEWORK="$(find "$ROOT_DIR/.build" -path "*/Sparkle.framework" -type d -print -quit 2>/dev/null || true)"
fi
if [[ -n "$SPARKLE_FRAMEWORK" ]]; then
  cp -R "$SPARKLE_FRAMEWORK" "$FRAMEWORKS_DIR/"
  if ! otool -l "$APP_BINARY" | grep -q "@executable_path/../Frameworks"; then
    install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_BINARY"
  fi
fi

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>Ghost</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$APP_BUILD</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleIconFile</key>
  <string>Ghost</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSMicrophoneUsageDescription</key>
  <string>Ghost uses the microphone for dictation.</string>
  <key>NSSpeechRecognitionUsageDescription</key>
  <string>Ghost uses speech recognition to turn your voice into prompts.</string>
  <key>NSCalendarsUsageDescription</key>
  <string>Ghost uses Calendar access to read and create events you request.</string>
  <key>NSCalendarsFullAccessUsageDescription</key>
  <string>Ghost uses Calendar access to read and create events you request.</string>
  <key>NSRemindersUsageDescription</key>
  <string>Ghost uses Reminders access to create reminders you request.</string>
  <key>NSRemindersFullAccessUsageDescription</key>
  <string>Ghost uses Reminders access to create reminders you request.</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>Ghost uses Apple Events only for requested local app automation such as Reminders fallback actions.</string>
</dict>
</plist>
PLIST

if [[ -n "$SPARKLE_FEED_URL" ]]; then
  /usr/libexec/PlistBuddy -c "Add :SUFeedURL string $SPARKLE_FEED_URL" "$INFO_PLIST" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Set :SUFeedURL $SPARKLE_FEED_URL" "$INFO_PLIST"
fi

if [[ -n "$SPARKLE_PUBLIC_ED_KEY" ]]; then
  /usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string $SPARKLE_PUBLIC_ED_KEY" "$INFO_PLIST" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Set :SUPublicEDKey $SPARKLE_PUBLIC_ED_KEY" "$INFO_PLIST"
fi

codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  --bundle-only|bundle)
    ;;
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--bundle-only|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac

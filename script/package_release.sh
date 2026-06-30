#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Ghost"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${GHOST_VERSION:?Set GHOST_VERSION, for example 1.0.1}"
BUILD="${GHOST_BUILD:?Set GHOST_BUILD, for example 101}"
FEED_URL="${SPARKLE_FEED_URL:?Set SPARKLE_FEED_URL, for example https://example.com/ghost/appcast.xml}"
PUBLIC_KEY="${SPARKLE_PUBLIC_ED_KEY:?Set SPARKLE_PUBLIC_ED_KEY from Sparkle generate_keys}"
RELEASE_DIR="${RELEASE_DIR:-$ROOT_DIR/releases/ghost}"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
ARCHIVE="$RELEASE_DIR/$APP_NAME-$VERSION.zip"

if [[ -z "${DEVELOPER_DIR:-}" && -d "/Applications/Xcode-beta.app/Contents/Developer" ]]; then
  export DEVELOPER_DIR="/Applications/Xcode-beta.app/Contents/Developer"
fi

mkdir -p "$RELEASE_DIR"

GHOST_VERSION="$VERSION" \
GHOST_BUILD="$BUILD" \
SPARKLE_FEED_URL="$FEED_URL" \
SPARKLE_PUBLIC_ED_KEY="$PUBLIC_KEY" \
  "$ROOT_DIR/script/build_and_run.sh" --bundle-only

if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
  codesign --force --deep --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$APP_BUNDLE"
fi

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  NOTARY_ARCHIVE="$RELEASE_DIR/$APP_NAME-$VERSION-notary.zip"
  rm -f "$NOTARY_ARCHIVE"
  ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$NOTARY_ARCHIVE"
  xcrun notarytool submit "$NOTARY_ARCHIVE" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP_BUNDLE"
  rm -f "$NOTARY_ARCHIVE"
fi

rm -f "$ARCHIVE"
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ARCHIVE"

if [[ -n "${SPARKLE_TOOLS_DIR:-}" ]]; then
  "$SPARKLE_TOOLS_DIR/generate_appcast" "$RELEASE_DIR"
else
  cat <<MSG
Created $ARCHIVE

Set SPARKLE_TOOLS_DIR to your Sparkle bin folder and rerun this script to
generate or update appcast.xml automatically.
MSG
fi

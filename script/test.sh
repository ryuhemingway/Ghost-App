#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${DEVELOPER_DIR:-}" && -d "/Applications/Xcode-beta.app/Contents/Developer" ]]; then
  export DEVELOPER_DIR="/Applications/Xcode-beta.app/Contents/Developer"
fi

swift build
BUILD_BIN_DIR="$(swift build --show-bin-path)"
PACKAGE_FRAMEWORKS_DIR="$BUILD_BIN_DIR/PackageFrameworks"

if [[ -d "$BUILD_BIN_DIR/Sparkle.framework" ]]; then
  mkdir -p "$PACKAGE_FRAMEWORKS_DIR"
  rm -rf "$PACKAGE_FRAMEWORKS_DIR/Sparkle.framework"
  cp -R "$BUILD_BIN_DIR/Sparkle.framework" "$PACKAGE_FRAMEWORKS_DIR/Sparkle.framework"
fi

swift test

#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_PATH="$ROOT_DIR/build/DerivedData"
CONFIGURATION="${CONFIGURATION:-Release}"
TEAM_ID="${TEAM_ID:-}"
BUNDLE_ID="${BUNDLE_ID:-com.xiaohou31549.SecretSync}"
APP_NAME="SecretSync.app"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$APP_NAME"
DIST_DIR="$ROOT_DIR/dist"
STAGING_DIR="$DIST_DIR/dmg-root"
DMG_PATH="$DIST_DIR/SecretSync.dmg"

TEAM_ID="$TEAM_ID" BUNDLE_ID="$BUNDLE_ID" CONFIGURATION="$CONFIGURATION" "$ROOT_DIR/scripts/build_app.sh"

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR" "$DIST_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"
rm -f "$DMG_PATH"

hdiutil create \
  -volname "SecretSync" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "DMG 已生成: $DMG_PATH"

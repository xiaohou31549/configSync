#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_PATH="$ROOT_DIR/build/DerivedData"
CONFIGURATION="${CONFIGURATION:-Release}"
TEAM_ID="${TEAM_ID:-}"
BUNDLE_ID="${BUNDLE_ID:-com.xiaohou31549.SecretSync}"
APP_NAME="SecretSync.app"
APP_PATH="${APP_PATH:-$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$APP_NAME}"
DIST_DIR="$ROOT_DIR/dist"
STAGING_DIR="$DIST_DIR/dmg-root"
DMG_NAME="${DMG_NAME:-SecretSync}"
DMG_PATH="$DIST_DIR/$DMG_NAME.dmg"
SKIP_BUILD="${SKIP_BUILD:-0}"
DRY_RUN="${DRY_RUN:-0}"

run_cmd() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[DRY_RUN] '
    printf '%q ' "$@"
    printf '\n'
    return 0
  fi

  "$@"
}

if [[ "$SKIP_BUILD" != "1" ]]; then
  TEAM_ID="$TEAM_ID" BUNDLE_ID="$BUNDLE_ID" CONFIGURATION="$CONFIGURATION" DRY_RUN="$DRY_RUN" "$ROOT_DIR/scripts/build_app.sh"
fi

if [[ "$DRY_RUN" == "1" ]]; then
  echo "[DRY_RUN] rm -rf $STAGING_DIR"
  echo "[DRY_RUN] mkdir -p $STAGING_DIR $DIST_DIR"
  echo "[DRY_RUN] cp -R $APP_PATH $STAGING_DIR/"
  echo "[DRY_RUN] ln -s /Applications $STAGING_DIR/Applications"
  echo "[DRY_RUN] rm -f $DMG_PATH"
else
  rm -rf "$STAGING_DIR"
  mkdir -p "$STAGING_DIR" "$DIST_DIR"
  cp -R "$APP_PATH" "$STAGING_DIR/"
  ln -s /Applications "$STAGING_DIR/Applications"
  rm -f "$DMG_PATH"
fi

run_cmd hdiutil create \
  -volname "SecretSync" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "DMG 已生成: $DMG_PATH"

#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT_DIR/build/SecretSync.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$ROOT_DIR/dist/export}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
EXPORT_OPTIONS_PLIST="${EXPORT_OPTIONS_PLIST:-$ROOT_DIR/packaging/ExportOptions-DeveloperID.plist}"
APP_NAME="${APP_NAME:-SecretSync}"
APP_BUNDLE_NAME="${APP_BUNDLE_NAME:-$APP_NAME.app}"
DMG_NAME="${DMG_NAME:-$APP_NAME}"
BUNDLE_ID="${BUNDLE_ID:-com.xiaohou31549.SecretSync}"
SCHEME="${SCHEME:-SecretSync}"
TEAM_ID="${TEAM_ID:-}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application}"
NOTARY_KEYCHAIN_PROFILE="${NOTARY_KEYCHAIN_PROFILE:-}"
NOTARY_PROFILE_NAME="${NOTARY_PROFILE_NAME:-SecretSync-Notary}"
APPLE_ID="${APPLE_ID:-}"
APP_SPECIFIC_PASSWORD="${APP_SPECIFIC_PASSWORD:-}"
SKIP_NOTARIZATION="${SKIP_NOTARIZATION:-0}"
DRY_RUN="${DRY_RUN:-0}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "缺少命令: $1"
    exit 1
  fi
}

run_cmd() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[DRY_RUN] '
    printf '%q ' "$@"
    printf '\n'
    return 0
  fi

  "$@"
}

if [[ -z "$TEAM_ID" ]]; then
  echo "缺少 TEAM_ID。用法: TEAM_ID=你的TeamID scripts/release_notarized_dmg.sh"
  exit 1
fi

require_cmd xcodebuild
require_cmd xcrun
require_cmd hdiutil
require_cmd codesign
require_cmd spctl

cd "$ROOT_DIR"

TEAM_ID="$TEAM_ID" \
BUNDLE_ID="$BUNDLE_ID" \
SCHEME="$SCHEME" \
SIGNING_IDENTITY="$SIGNING_IDENTITY" \
DRY_RUN="$DRY_RUN" \
"$ROOT_DIR/scripts/archive_release.sh"

if [[ "$DRY_RUN" == "1" ]]; then
  echo "[DRY_RUN] rm -rf $EXPORT_PATH"
else
  rm -rf "$EXPORT_PATH"
fi

run_cmd xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"

EXPORTED_APP_PATH="$EXPORT_PATH/$APP_BUNDLE_NAME"

APP_PATH="$EXPORTED_APP_PATH" \
SKIP_BUILD=1 \
DMG_NAME="$DMG_NAME" \
DRY_RUN="$DRY_RUN" \
"$ROOT_DIR/scripts/package_dmg.sh"

DMG_PATH="$DIST_DIR/$DMG_NAME.dmg"

run_cmd codesign --force --sign "$SIGNING_IDENTITY" --timestamp "$DMG_PATH"

if [[ "$SKIP_NOTARIZATION" != "1" ]]; then
  if [[ -z "$NOTARY_KEYCHAIN_PROFILE" ]]; then
    if [[ -z "$APPLE_ID" || -z "$APP_SPECIFIC_PASSWORD" ]]; then
      echo "缺少公证凭据。请提供 NOTARY_KEYCHAIN_PROFILE，或同时提供 APPLE_ID 与 APP_SPECIFIC_PASSWORD。"
      exit 1
    fi

    if [[ "$DRY_RUN" == "1" ]]; then
      run_cmd xcrun notarytool store-credentials "$NOTARY_PROFILE_NAME" \
        --apple-id "$APPLE_ID" \
        --team-id "$TEAM_ID" \
        --password "$APP_SPECIFIC_PASSWORD"
    elif ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE_NAME" >/dev/null 2>&1; then
      run_cmd xcrun notarytool store-credentials "$NOTARY_PROFILE_NAME" \
        --apple-id "$APPLE_ID" \
        --team-id "$TEAM_ID" \
        --password "$APP_SPECIFIC_PASSWORD"
    fi

    NOTARY_KEYCHAIN_PROFILE="$NOTARY_PROFILE_NAME"
  fi

  run_cmd xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" \
    --wait

  run_cmd xcrun stapler staple "$DMG_PATH"
  run_cmd xcrun stapler validate "$DMG_PATH"
  run_cmd spctl -a -vvv -t open --context context:primary-signature "$DMG_PATH"
fi

run_cmd codesign --verify --deep --strict --verbose=2 "$EXPORTED_APP_PATH"

echo "发布产物已生成: $DMG_PATH"
if [[ "$SKIP_NOTARIZATION" == "1" ]]; then
  echo "当前为未公证构建；如需正式分发，请移除 SKIP_NOTARIZATION=1 后重跑。"
else
  echo "公证与签名校验已完成。"
fi

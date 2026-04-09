#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/SecretSync.xcodeproj"
ARCHIVE_PATH="$ROOT_DIR/build/SecretSync.xcarchive"
SOURCE_PACKAGES_DIR="$ROOT_DIR/build/SourcePackages"
SCHEME="${SCHEME:-SecretSync}"
TEAM_ID="${TEAM_ID:-}"
BUNDLE_ID="${BUNDLE_ID:-com.xiaohou31549.SecretSync}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application}"
CODE_SIGN_STYLE="${CODE_SIGN_STYLE:-Manual}"
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

if [[ -z "$TEAM_ID" ]]; then
  echo "缺少 TEAM_ID。用法: TEAM_ID=你的TeamID scripts/archive_release.sh"
  exit 1
fi

cd "$ROOT_DIR"

if [[ ! -d "$PROJECT_PATH" ]]; then
  run_cmd "$ROOT_DIR/scripts/generate_xcodeproj.sh"
fi

if [[ "$DRY_RUN" == "1" ]]; then
  echo "[DRY_RUN] rm -rf $ARCHIVE_PATH"
else
  rm -rf "$ARCHIVE_PATH"
fi

run_cmd xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "platform=macOS" \
  -archivePath "$ARCHIVE_PATH" \
  -clonedSourcePackagesDirPath "$SOURCE_PACKAGES_DIR" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" \
  CODE_SIGN_STYLE="$CODE_SIGN_STYLE" \
  archive

echo "Archive 已生成: $ARCHIVE_PATH"

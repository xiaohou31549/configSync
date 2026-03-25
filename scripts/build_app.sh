#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/SecretSync.xcodeproj"
DERIVED_DATA_PATH="$ROOT_DIR/build/DerivedData"
SOURCE_PACKAGES_DIR="$ROOT_DIR/build/SourcePackages"
CONFIGURATION="${CONFIGURATION:-Release}"
SCHEME="${SCHEME:-SecretSync}"
TEAM_ID="${TEAM_ID:-}"
BUNDLE_ID="${BUNDLE_ID:-com.xiaohou31549.SecretSync}"

if [[ -z "$TEAM_ID" ]]; then
  echo "缺少 TEAM_ID。用法: TEAM_ID=你的TeamID scripts/build_app.sh"
  exit 1
fi

cd "$ROOT_DIR"

if [[ ! -d "$PROJECT_PATH" ]]; then
  "$ROOT_DIR/scripts/generate_xcodeproj.sh"
fi

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "platform=macOS" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -clonedSourcePackagesDirPath "$SOURCE_PACKAGES_DIR" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  CODE_SIGN_STYLE=Automatic \
  build

APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/SecretSync.app"

if [[ ! -d "$APP_PATH" ]]; then
  echo "构建成功，但未找到 .app: $APP_PATH"
  exit 1
fi

echo "构建完成: $APP_PATH"

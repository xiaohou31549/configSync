#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/SecretSync.xcodeproj"
DERIVED_DATA_PATH="$ROOT_DIR/build/UITestDerivedData"
SOURCE_PACKAGES_DIR="$ROOT_DIR/build/SourcePackages"
TEAM_ID="${TEAM_ID:-}"

if [[ -z "$TEAM_ID" ]]; then
  echo "缺少 TEAM_ID。用法：TEAM_ID=你的开发团队ID ./scripts/run_ui_tests.sh" >&2
  echo "说明：macOS XCUITest 需要有效签名，默认无团队 ID 时 Runner 无法加载测试 bundle。" >&2
  exit 1
fi

cd "$ROOT_DIR"

if [[ ! -d "$PROJECT_PATH" || "$ROOT_DIR/project.yml" -nt "$PROJECT_PATH/project.pbxproj" ]]; then
  "$ROOT_DIR/scripts/generate_xcodeproj.sh"
fi

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme SecretSyncUITests \
  -destination "platform=macOS" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -clonedSourcePackagesDirPath "$SOURCE_PACKAGES_DIR" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Automatic \
  test

#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/SecretSync.xcodeproj"
DERIVED_DATA_PATH="$ROOT_DIR/build/UITestDerivedData"
SOURCE_PACKAGES_DIR="$ROOT_DIR/build/SourcePackages"
TEAM_ID="${TEAM_ID:-}"
UI_TEST_INPUT_SOURCE="${UI_TEST_INPUT_SOURCE:-com.apple.keylayout.ABC}"
INPUT_SOURCE_SWITCHER=""
PREVIOUS_INPUT_SOURCE=""

if [[ -z "$TEAM_ID" ]]; then
  echo "缺少 TEAM_ID。用法：TEAM_ID=你的开发团队ID ./scripts/run_ui_tests.sh" >&2
  echo "说明：macOS XCUITest 需要有效签名，默认无团队 ID 时 Runner 无法加载测试 bundle。" >&2
  exit 1
fi

if command -v im-select >/dev/null 2>&1; then
  INPUT_SOURCE_SWITCHER="im-select"
elif command -v macism >/dev/null 2>&1; then
  INPUT_SOURCE_SWITCHER="macism"
fi

restore_input_source() {
  if [[ -n "$INPUT_SOURCE_SWITCHER" && -n "$PREVIOUS_INPUT_SOURCE" ]]; then
    "$INPUT_SOURCE_SWITCHER" "$PREVIOUS_INPUT_SOURCE" >/dev/null 2>&1 || true
  fi
}

if [[ -n "$INPUT_SOURCE_SWITCHER" ]]; then
  PREVIOUS_INPUT_SOURCE="$("$INPUT_SOURCE_SWITCHER")"
  trap restore_input_source EXIT
  "$INPUT_SOURCE_SWITCHER" "$UI_TEST_INPUT_SOURCE"
  echo "已切换输入法到: $UI_TEST_INPUT_SOURCE"
else
  echo "警告：未检测到 im-select 或 macism，无法在脚本内自动切换输入法。" >&2
  echo "建议先手动切到系统输入法（例如 ABC），再运行 UI 测试。" >&2
fi

cd "$ROOT_DIR"

if [[ ! -d "$PROJECT_PATH" || "$ROOT_DIR/project.yml" -nt "$PROJECT_PATH/project.pbxproj" ]]; then
  "$ROOT_DIR/scripts/generate_xcodeproj.sh"
fi

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme SecretSync \
  -destination "platform=macOS" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -clonedSourcePackagesDirPath "$SOURCE_PACKAGES_DIR" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Automatic \
  CODE_SIGN_IDENTITY="Apple Development" \
  -only-testing:SecretSyncUITests \
  test

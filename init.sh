#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_PATH="$ROOT_DIR/SecretSync.xcodeproj"
DERIVED_DATA_PATH="$ROOT_DIR/build/DerivedData"
SOURCE_PACKAGES_DIR="$ROOT_DIR/build/SourcePackages"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug/SecretSync.app"
HARNESS_DIR="$ROOT_DIR/.harness"
AUTH_DIR="$HARNESS_DIR/auth"
LOG_PATH="$HARNESS_DIR/app.log"
PID_PATH="$HARNESS_DIR/app.pid"
KEYCHAIN_SERVICE="com.tough.SecretSync.harness"

mkdir -p "$HARNESS_DIR" "$AUTH_DIR" "$ROOT_DIR/build"

if [[ ! -d "$PROJECT_PATH" || "$ROOT_DIR/project.yml" -nt "$PROJECT_PATH/project.pbxproj" ]]; then
  "$ROOT_DIR/scripts/generate_xcodeproj.sh"
fi

swift package resolve
python3 "$ROOT_DIR/scripts/validate_feature_list.py" "$ROOT_DIR/feature_list.json"
python3 "$ROOT_DIR/scripts/doc_gardening.py"

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme SecretSync \
  -destination "platform=macOS" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -clonedSourcePackagesDirPath "$SOURCE_PACKAGES_DIR" \
  test \
  -only-testing:SecretSyncKitTests

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme SecretSync \
  -configuration Debug \
  -destination "platform=macOS" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -clonedSourcePackagesDirPath "$SOURCE_PACKAGES_DIR" \
  build

if [[ "${NO_LAUNCH:-0}" != "1" ]]; then
  if [[ -f "$PID_PATH" ]]; then
    EXISTING_PID="$(cat "$PID_PATH" || true)"
    if [[ -n "${EXISTING_PID:-}" ]] && kill -0 "$EXISTING_PID" 2>/dev/null; then
      kill "$EXISTING_PID" || true
    fi
  fi

  env \
    SECRET_SYNC_HARNESS=1 \
    SECRET_SYNC_USE_IN_MEMORY_STORE=1 \
    SECRET_SYNC_USE_MOCK_SERVICES=1 \
    SECRET_SYNC_SKIP_SESSION_RESTORE=1 \
    SECRET_SYNC_AUTH_SETTINGS_DIR="$AUTH_DIR" \
    SECRET_SYNC_KEYCHAIN_SERVICE="$KEYCHAIN_SERVICE" \
    "$APP_PATH/Contents/MacOS/SecretSync" \
    >"$LOG_PATH" 2>&1 &

  echo $! > "$PID_PATH"
  echo "Harness 应用已启动，PID=$(cat "$PID_PATH")"
  echo "日志：$LOG_PATH"
else
  echo "已跳过启动应用（NO_LAUNCH=1）"
fi

echo "初始化完成"

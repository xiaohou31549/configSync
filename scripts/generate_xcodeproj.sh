#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

xcodegen generate

SHARED_SCHEMES_DIR="$ROOT_DIR/SecretSync.xcodeproj/xcshareddata/xcschemes"
mkdir -p "$SHARED_SCHEMES_DIR"
cp "$ROOT_DIR/scripts/templates/SecretSyncUITests.xcscheme" "$SHARED_SCHEMES_DIR/SecretSyncUITests.xcscheme"

echo "已生成工程: $ROOT_DIR/SecretSync.xcodeproj"

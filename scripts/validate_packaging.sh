#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
OUTPUT_FILE="$TMP_DIR/release_dry_run.log"
trap 'rm -rf "$TMP_DIR"' EXIT

cd "$ROOT_DIR"

zsh -n scripts/build_app.sh
zsh -n scripts/archive_release.sh
zsh -n scripts/package_dmg.sh
zsh -n scripts/release_notarized_dmg.sh

DRY_RUN=1 \
TEAM_ID=TESTTEAM123 \
APPLE_ID=test@example.com \
APP_SPECIFIC_PASSWORD=dummy-app-password \
NOTARY_PROFILE_NAME=SecretSync-Notary-Test \
scripts/release_notarized_dmg.sh >"$OUTPUT_FILE"

grep -q "xcodebuild .* archive" "$OUTPUT_FILE"
grep -Fq "xcodebuild -exportArchive" "$OUTPUT_FILE"
grep -Fq "hdiutil create" "$OUTPUT_FILE"
grep -Fq "xcrun notarytool submit" "$OUTPUT_FILE"
grep -Fq "xcrun stapler staple" "$OUTPUT_FILE"
grep -Fq "spctl -a -vvv -t open" "$OUTPUT_FILE"

echo "packaging 校验通过"

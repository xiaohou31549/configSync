#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

CHECK_ONLY=0
REPORT_PATH="build/housekeeping-report.txt"

for arg in "$@"; do
  case "$arg" in
    --check)
      CHECK_ONLY=1
      ;;
    *)
      REPORT_PATH="$arg"
      ;;
  esac
done

mkdir -p "$(dirname "$REPORT_PATH")"

placeholder_hits="$(rg -n 'Placeholder|TODO|FIXME|HACK' Sources Tests || true)"
env_hits="$(rg -n 'ProcessInfo\\.processInfo\\.environment' Sources Tests || true)"

{
  echo "# Housekeeping Report"
  echo
  echo "## Placeholder 与临时痕迹"
  if [[ -n "$placeholder_hits" ]]; then
    echo "$placeholder_hits"
  else
    echo "未发现"
  fi
  echo
  echo "## ProcessInfo 环境读取"
  if [[ -n "$env_hits" ]]; then
    echo "$env_hits"
  else
    echo "未发现"
  fi
} > "$REPORT_PATH"

if [[ "$CHECK_ONLY" == "1" ]]; then
  if [[ -n "$placeholder_hits" || -n "$env_hits" ]]; then
    echo "后台清理扫描发现待处理项。修复方法：优先替换 Placeholder，实现或删除 TODO/FIXME/HACK，并把环境读取收敛到 HarnessRuntime。" >&2
    exit 1
  fi
fi

echo "后台清理扫描完成：$REPORT_PATH"

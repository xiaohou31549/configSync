#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  echo "架构边界校验失败：$1" >&2
  exit 1
}

search() {
  local pattern="$1"
  shift

  if command -v rg >/dev/null 2>&1; then
    rg -n "$pattern" "$@"
  else
    grep -RInE "$pattern" "$@"
  fi
}

if search 'import (SwiftUI|AppKit|SQLite3)' Sources/SecretSyncKit/Domain >/dev/null; then
  fail "Domain 层不允许依赖 SwiftUI/AppKit/SQLite3。修复方法：把 UI 或存储实现移动到 Presentation/Infrastructure，并让 Domain 只保留实体和协议。"
fi

if search 'import (SwiftUI|AppKit)' Sources/SecretSyncKit/Application >/dev/null; then
  fail "Application 层不允许依赖 UI 框架。修复方法：把界面状态和控件逻辑留在 Presentation，用 UseCase 暴露纯业务接口。"
fi

if search 'SQLiteConfigRepository|GitHubAPIClient|GitHubActionsAPIClient|GitHubAuthRepository|KeychainStore|FileAuthSettingsStore' Sources/SecretSyncKit/Presentation | grep -v 'AppContainer.swift' >/dev/null; then
  fail "Presentation 层发现对 Infrastructure 具体实现的直接依赖。修复方法：只允许在 AppContainer 装配具体实现，其他视图和 ViewModel 仅依赖 UseCase、实体或协议。"
fi

if search 'ProcessInfo\\.processInfo\\.environment' Sources | grep -v 'HarnessRuntime.swift' >/dev/null; then
  fail "环境变量读取必须集中在 HarnessRuntime。修复方法：把环境读取抽到 HarnessRuntime，再通过 AppContainer 注入。"
fi

echo "架构边界校验通过"

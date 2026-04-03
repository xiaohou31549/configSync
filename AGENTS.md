# SecretSync 智能体目录

## 1. 目标
- 本仓库是一个 macOS 原生桌面应用，用于本地管理 GitHub Actions Secrets / Variables，并批量同步到多个仓库。
- 本文件不是完整规范书，只提供入口、边界和标准工作流。

## 2. 先看哪里
- 产品目标：`docs/PRODUCT_SPEC.md`
- 架构边界：`docs/ARCHITECTURE.md`
- 实施路线：`docs/EXECUTION_PLAN.md`
- Harness 约束：`docs/HARNESS_ENGINEERING.md`
- 测试策略：`docs/TESTING_STRATEGY.md`
- 数据结构：`docs/DATABASE_SCHEMA.md`
- 历史输入材料：`github-secrets-manager-prd.md`、`github-secrets-manager-tech-spec.md`

## 3. 代码地图
- App 入口：`Sources/SecretSyncApp/App/SecretSyncApp.swift`
- 组合根：`Sources/SecretSyncKit/Presentation/Shared/AppContainer.swift`
- 顶层视图：`Sources/SecretSyncKit/Presentation/Shared/RootView.swift`
- 页面状态：`Sources/SecretSyncKit/Presentation/Shared/AppViewModel.swift`
- 表现层：`Sources/SecretSyncKit/Presentation/**`
- 用例层：`Sources/SecretSyncKit/Application/UseCases/**`
- 领域层：`Sources/SecretSyncKit/Domain/**`
- 基础设施层：`Sources/SecretSyncKit/Infrastructure/**`
- 单元测试：`Tests/SecretSyncKitTests/**`
- UI 测试：`Tests/SecretSyncUITests/**`

## 4. 工程脚手架入口
- 初始化环境：`./init.sh`
- 工作进度日志：`project-progress.txt`
- 功能状态表：`feature_list.json`
- 文档园丁：`python3 scripts/doc_gardening.py`
- 架构边界检查：`./scripts/check_architecture.sh`
- 功能表校验：`python3 scripts/validate_feature_list.py feature_list.json`
- 桌面端 E2E：`TEAM_ID=你的开发团队ID ./scripts/run_ui_tests.sh`
- 后台清理扫描：`./scripts/housekeeping_scan.sh`

## 5. 智能体标准开发循环
1. 阅读 `git log --oneline -5` 和 `project-progress.txt`
2. 运行 `./init.sh`
3. 读取 `feature_list.json`
4. 只挑一个最高优先级且 `passes=false` 的功能
5. 先写或修改验证，再做实现
6. 完成后只通过修改 `feature_list.json` 的 `passes` 字段更新状态
7. 追加写入 `project-progress.txt`
8. 提交 Git Commit，摘要必须说明改了什么、如何验证

## 6. 架构硬边界
- `Domain` 不能依赖 `SwiftUI`、`AppKit`、`SQLite3`、网络实现。
- `Application` 只能编排用例，不能直接触碰 UI 框架。
- `Presentation` 不允许直接 new 具体基础设施实现，唯一例外是组合根 `AppContainer.swift`。
- `Infrastructure` 负责 GitHub API、SQLite、Keychain、OAuth、加密等外部能力。
- 新增跨层依赖前，先更新 `docs/ARCHITECTURE.md`，再更新边界检查脚本。

## 7. Harness 运行模式
- UI 测试与自动化必须使用 Harness 环境变量，不要污染真实本地数据。
- 关键环境变量：
- `SECRET_SYNC_HARNESS=1`
- `SECRET_SYNC_USE_IN_MEMORY_STORE=1`
- `SECRET_SYNC_SKIP_SESSION_RESTORE=1`
- `SECRET_SYNC_AUTH_SETTINGS_DIR=<临时目录>`
- `SECRET_SYNC_KEYCHAIN_SERVICE=<唯一 service>`

## 8. 针对本仓库的验证优先级
- 第一优先：`xcodebuild test` 单元测试
- 第二优先：macOS `XCUITest` 冒烟与关键路径（通过 `scripts/run_ui_tests.sh` 独立执行）
- 第三优先：脚本校验，包括文档、架构、特性表
- 浏览器自动化不是主路径；仅在验证 OAuth 回调页或未来 Web 配套页面时使用

## 9. 文档维护规则
- `docs/` 是一级事实来源，尽量不要把规范散落在根目录
- `docs/ARCHITECTURE.md` 内含自动生成片段，由 `scripts/doc_gardening.py` 维护
- 文档变更若影响事实，应同步更新脚本或测试
- 若文档和代码冲突，以代码与测试结果为准，并立即修文档

## 10. 功能表规则
- `feature_list.json` 必须是稳定 JSON
- 每个条目至少包含：`id`、`title`、`priority`、`description`、`verification`、`passes`
- 不要在进度文件中手写“已完成”替代 JSON 状态
- 未验证通过的功能一律保持 `passes=false`

## 11. Git 与提交
- 提交信息使用 Conventional Commits
- 小步提交，避免把多个独立功能混在一个提交里
- 提交前至少运行与改动相符的最小验证
- 没验证的内容要在提交说明或进度日志中明确写出

## 12. 新增代码时的默认做法
- 优先沿用现有分层，不要随手增加“工具类大杂烩”
- 先补可访问性标识，再写 UI 自动化
- 尽量把环境注入放到组合根，不要把 `ProcessInfo` 散落全仓
- 对外部依赖写协议边界，便于 mock

## 13. 常用命令
```bash
./init.sh
xcodebuild -project SecretSync.xcodeproj -scheme SecretSync -destination "platform=macOS" test
TEAM_ID=你的开发团队ID ./scripts/run_ui_tests.sh
python3 scripts/doc_gardening.py --check
./scripts/check_architecture.sh
python3 scripts/validate_feature_list.py feature_list.json
./scripts/housekeeping_scan.sh --check
```

## 14. 修改前自查
- 这次改动是否跨层？
- 是否需要更新 `feature_list.json`？
- 是否需要更新 `project-progress.txt`？
- 是否需要补 UI 标识或测试？
- 是否会让 `docs/` 失真？

## 15. 不要做什么
- 不要把长篇操作手册塞进本文件
- 不要绕过 `AppContainer` 在视图层直接接基础设施
- 不要让 UI 测试读写真实用户数据库或 Keychain
- 不要把“将来再清理”当成默认方案

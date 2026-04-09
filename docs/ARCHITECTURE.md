# 架构说明

SecretSync 采用单模块分层架构：`Presentation -> Application -> Domain <- Infrastructure`，并由 `AppContainer` 作为唯一组合根负责装配依赖。

## 分层职责
- `Presentation`：SwiftUI 界面、页面状态、可访问性标识、UI 测试支点。
- `Application`：用例编排与输入校验，不感知 SwiftUI 和具体外部实现。
- `Domain`：实体、协议、同步结果、业务规则。
- `Infrastructure`：GitHub App API、安装/授权会话、SQLite、加密、配置文件。

## 当前组合根
- 入口应用：`Sources/SecretSyncApp/App/SecretSyncApp.swift`
- 组合根：`Sources/SecretSyncKit/Presentation/Shared/AppContainer.swift`
- 组合根始终装配真实 GitHub App 认证、仓库目录与同步实现；Harness 只隔离数据存储、会话恢复与本地配置目录。
- GitHub App 配置加载顺序为：环境变量 -> 本地 `auth.json` 覆盖值 -> 应用包内置 `BundledGitHubApp.json`；这样发布包可直接提供默认登录能力，同时保留本地覆盖入口。
- 当前 Presentation 默认只暴露 Secret 编辑与同步路径；`ConfigItemType.variable` 与对应 GitHub API 封装仍保留在 Domain / Infrastructure，供后续版本扩展。

## 强制边界
- `Domain` 禁止依赖 UI 和系统存储实现。
- `Application` 禁止依赖 UI 框架。
- `Presentation` 除组合根外，禁止直接引用 `Infrastructure` 中的具体类型。
- 环境变量读取集中在 Harness 运行时配置中，不散落到视图与用例。

## 运行时模式
- 正常模式：SQLite + 本地配置文件 + GitHub App 认证与仓库 API。
- Harness 模式：临时目录、可选 In-Memory 仓库、跳过会话恢复；认证链路仍生成真实 GitHub App 授权地址，但不自动打开浏览器。

## GitHub App 本地存储约束
- 本地 GitHub App 覆盖配置统一写入 `auth.json`，包括 `App ID`、`Client ID`、`Client Secret`、`Slug`、私钥路径、回调地址。
- GitHub 登录会话与安装访问令牌统一写入本地 `auth-session.json`；应用运行时不再读写 macOS Keychain。
- 私钥 PEM 文件不复制到应用数据目录，运行时只引用用户提供的本地路径。
- 若检测到旧版 `GitHubAuthConfiguration` 格式文件，应用应在读取时迁移为当前 `StoredGitHubAuthConfiguration` 结构，并保留 `Client Secret` 于本地文件。
- 发布包若提供内置 `BundledGitHubApp.json` 与配套 PEM 资源，则该配置作为普通用户默认路径；一旦用户在应用内保存覆盖值，运行时应优先读取本地覆盖配置。

## 自动生成事实
<!-- GENERATED:BEGIN -->
_由 `python3 scripts/doc_gardening.py` 维护，请勿手改此区块。_
- Swift tools version：6.0
- macOS deployment target：14.0
- Xcode targets：SecretSync, SecretSyncKitTests, SecretSyncUITests
- Scripts：archive_release.sh, build_app.sh, check_architecture.sh, doc_gardening.py, generate_app_icon.swift, generate_xcodeproj.sh, housekeeping_scan.sh, package_dmg.sh, release_notarized_dmg.sh, run_ui_tests.sh, validate_feature_list.py, validate_packaging.sh
- Docs：ARCHITECTURE.md, DATABASE_SCHEMA.md, EXECUTION_PLAN.md, HARNESS_ENGINEERING.md, PRODUCT_SPEC.md, README.md, TESTING_STRATEGY.md
- 关键校验入口：`./init.sh`、`./scripts/check_architecture.sh`、`python3 scripts/validate_feature_list.py feature_list.json`
<!-- GENERATED:END -->

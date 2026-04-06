# 架构说明

SecretSync 采用单模块分层架构：`Presentation -> Application -> Domain <- Infrastructure`，并由 `AppContainer` 作为唯一组合根负责装配依赖。

## 分层职责
- `Presentation`：SwiftUI 界面、页面状态、可访问性标识、UI 测试支点。
- `Application`：用例编排与输入校验，不感知 SwiftUI 和具体外部实现。
- `Domain`：实体、协议、同步结果、业务规则。
- `Infrastructure`：GitHub App API、安装/授权会话、SQLite、Keychain、加密、配置文件。

## 当前组合根
- 入口应用：`Sources/SecretSyncApp/App/SecretSyncApp.swift`
- 组合根：`Sources/SecretSyncKit/Presentation/Shared/AppContainer.swift`
- 组合根始终装配真实 GitHub App 认证、仓库目录与同步实现；Harness 只隔离数据存储、Keychain service 与会话恢复。
- 当前 Presentation 默认只暴露 Secret 编辑与同步路径；`ConfigItemType.variable` 与对应 GitHub API 封装仍保留在 Domain / Infrastructure，供后续版本扩展。

## 强制边界
- `Domain` 禁止依赖 UI 和系统存储实现。
- `Application` 禁止依赖 UI 框架。
- `Presentation` 除组合根外，禁止直接引用 `Infrastructure` 中的具体类型。
- 环境变量读取集中在 Harness 运行时配置中，不散落到视图与用例。

## 运行时模式
- 正常模式：SQLite + Keychain + GitHub App 认证与仓库 API。
- Harness 模式：临时目录、独立 Keychain service、可选 In-Memory 仓库、跳过会话恢复；认证链路仍生成真实 GitHub App 授权地址，但不自动打开浏览器。

## GitHub App 本地存储约束
- `Client Secret` 只允许进入当前用户 Keychain，不允许写入 `auth.json`、SQLite、`UserDefaults` 或提交到仓库。
- `auth.json` 只保存 GitHub App 元数据：`App ID`、`Client ID`、`Slug`、私钥路径、回调地址。
- 私钥 PEM 文件不复制到应用数据目录，运行时只引用用户提供的本地路径。
- 若检测到旧版 `auth.json` 仍内嵌 `Client Secret`，应用应在读取时自动迁移到 Keychain，并把文件净化为仅保留元数据。

## 自动生成事实
<!-- GENERATED:BEGIN -->
_由 `python3 scripts/doc_gardening.py` 维护，请勿手改此区块。_
- Swift tools version：6.0
- macOS deployment target：14.0
- Xcode targets：SecretSync, SecretSyncKitTests, SecretSyncUITests
- Scripts：archive_release.sh, build_app.sh, check_architecture.sh, doc_gardening.py, generate_app_icon.swift, generate_xcodeproj.sh, housekeeping_scan.sh, package_dmg.sh, run_ui_tests.sh, validate_feature_list.py
- Docs：ARCHITECTURE.md, DATABASE_SCHEMA.md, EXECUTION_PLAN.md, HARNESS_ENGINEERING.md, PRODUCT_SPEC.md, README.md, TESTING_STRATEGY.md
- 关键校验入口：`./init.sh`、`./scripts/check_architecture.sh`、`python3 scripts/validate_feature_list.py feature_list.json`
<!-- GENERATED:END -->

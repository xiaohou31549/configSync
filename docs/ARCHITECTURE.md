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
- 组合根根据 Harness 环境变量切换真实实现或测试替身。

## 强制边界
- `Domain` 禁止依赖 UI 和系统存储实现。
- `Application` 禁止依赖 UI 框架。
- `Presentation` 除组合根外，禁止直接引用 `Infrastructure` 中的具体类型。
- 环境变量读取集中在 Harness 运行时配置中，不散落到视图与用例。

## 运行时模式
- 正常模式：SQLite + Keychain + 配置感知 GitHub App 服务。
- Harness 模式：临时目录、独立 Keychain service、可选 In-Memory 仓库、Mock GitHub 服务、跳过会话恢复。

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

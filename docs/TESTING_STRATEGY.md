# 测试与观测策略

## 测试金字塔
- 单元测试：用例、仓储、GitHub App 配置、安装授权会话、同步规则
- UI 测试：macOS 冒烟、关键编辑路径、截图
- 脚本校验：架构边界、文档事实、功能表结构、后台清理规则、发布脚本干运行链路

## 当前实现已覆盖的同步回归
- `AppViewModel` 只在同步前置条件满足时触发执行，并把 `SyncSummary` 保留到页面状态，供结果面板展示成功/失败摘要
- `GitHubSyncExecutor` 已覆盖多仓库、多配置项执行，以及 GitHub Secret / Variable 上传的成功与失败分支
- 当前 UI 默认路径只暴露 Secret；Variable 相关回归以领域层和基础设施层单元测试为主，避免文档误判为“代码已删除”

## 当前必须覆盖的存储回归
- GitHub App 配置保存后，`Client Secret` 必须随本地覆盖配置一起写入 `auth.json`
- 旧版包含 `Client Secret` 的 `GitHubAuthConfiguration` 文件必须可读取，并在读取后自动迁移到当前本地存储格式
- 覆盖目录下保存的 `auth.json` 必须能被同一覆盖目录下的配置加载器读取，避免 Harness 与临时目录模式出现“保存成功但登录读不到配置”
- 应用内置 `BundledGitHubApp.json` 存在时，配置加载器必须可解析内置 `Client Secret` 与 PEM 资源路径；若同时存在本地 `auth.json`，必须由本地覆盖配置优先
- Harness 测试必须使用独立临时目录保存 `auth-session.json` 会话数据，避免污染真实登录会话
- 私钥路径只验证路径读写与加载，不在测试中把 PEM 内容写入应用配置文件

## 推荐命令
```bash
xcodebuild -project SecretSync.xcodeproj -scheme SecretSync -destination "platform=macOS" -only-testing:SecretSyncKitTests test
TEAM_ID=你的开发团队ID ./scripts/run_ui_tests.sh
python3 scripts/doc_gardening.py --check
./scripts/check_architecture.sh
python3 scripts/validate_feature_list.py feature_list.json
./scripts/housekeeping_scan.sh --check
./scripts/validate_packaging.sh
```

## 桌面端 E2E 方案
- 工具：`XCTest / XCUITest`
- 断言对象：按钮、输入框、列表项、静态文本、同步结果、截图附件
- 环境：Harness 模式，不使用真实数据库和真实用户数据目录
- Harness 下不再回退 mock GitHub 服务；UI 测试验证真实 GitHub App 授权 URL 的生成、展示与本地回调等待状态
- macOS UI Runner 需要可用的开发团队签名；因此它作为独立命令执行，而不是默认阻塞 CI
- GitHub Actions 默认只运行 `SecretSyncKitTests`；`SecretSyncUITests` 由本机 `scripts/run_ui_tests.sh` 独立执行
- 运行 `scripts/run_ui_tests.sh` 时，脚本会优先使用 `im-select` 或 `macism` 将当前输入法切到系统输入法，默认值为 `com.apple.keylayout.ABC`，测试结束后再恢复原输入法
- 这样做是为了降低 `XCUITest` 通过 `testmanagerd` 模拟键盘输入时触发第三方输入法隐私弹窗的概率；若本机未安装输入法切换工具，脚本会给出警告并建议手动切换
- 如需覆盖默认输入法，可使用 `UI_TEST_INPUT_SOURCE=<输入法 ID> TEAM_ID=你的开发团队ID ./scripts/run_ui_tests.sh`

## 不把什么当作主验证
- 浏览器自动化不是主路径
- 人工口头验证不是回归防线
- 只写单元测试而没有 UI 冒烟，不足以覆盖桌面应用状态
- GitHub App 的人工安装成功一次，不等于后续回归已经被覆盖

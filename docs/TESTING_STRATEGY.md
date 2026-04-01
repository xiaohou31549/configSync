# 测试与观测策略

## 测试金字塔
- 单元测试：用例、仓储、GitHub App 配置、安装授权会话、同步规则
- UI 测试：macOS 冒烟、关键编辑路径、截图
- 脚本校验：架构边界、文档事实、功能表结构、后台清理规则

## 推荐命令
```bash
xcodebuild -project SecretSync.xcodeproj -scheme SecretSync -destination "platform=macOS" test
TEAM_ID=你的开发团队ID ./scripts/run_ui_tests.sh
python3 scripts/doc_gardening.py --check
./scripts/check_architecture.sh
python3 scripts/validate_feature_list.py feature_list.json
./scripts/housekeeping_scan.sh --check
```

## 桌面端 E2E 方案
- 工具：`XCTest / XCUITest`
- 断言对象：按钮、输入框、列表项、静态文本、同步结果、截图附件
- 环境：Harness 模式，不使用真实数据库和真实 Keychain service
- macOS UI Runner 需要可用的开发团队签名；因此它作为独立命令执行，而不是默认阻塞 CI

## 不把什么当作主验证
- 浏览器自动化不是主路径
- 人工口头验证不是回归防线
- 只写单元测试而没有 UI 冒烟，不足以覆盖桌面应用状态
- GitHub App 的人工安装成功一次，不等于后续回归已经被覆盖

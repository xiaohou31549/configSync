# Harness 落地计划

## 阶段 1：上下文显性化
- 建立 `AGENTS.md` 目录索引
- 建立 `docs/` 一级事实来源库
- 建立 `feature_list.json` 与 `project-progress.txt`

## 阶段 2：初始化脚手架
- 提供 `init.sh` 统一生成工程、构建、冒烟验证、可选启动应用
- 提供文档园丁脚本，自动修复生成型事实
- 提供功能表校验脚本，避免 JSON 漂移

## 阶段 3：标准开发循环
- 任何开发会话都先读取 Git 日志和进度文件
- 然后运行 `init.sh`
- 然后只挑一个 `passes=false` 的高优功能
- 完成后只通过改 JSON 状态表更新功能状态

## 阶段 4：验证与观测
- 单元测试保证核心业务逻辑
- macOS `XCUITest` 负责桌面端冒烟和关键路径
- GitHub App 安装授权、安装访问令牌与仓库范围选择需要有独立回归用例
- Harness 环境变量确保 UI 自动化不污染真实本地数据
- Harness 覆盖目录下的 GitHub App 配置保存与读取必须走同一路径，避免临时目录联调时落回“未配置”状态
- GitHub App 本地配置需要独立验证“文件只存元数据、Keychain 存 `Client Secret`、旧配置自动迁移”三类行为

## 阶段 5：机械化治理
- 架构边界由 `scripts/check_architecture.sh` 强制
- 文档事实由 `scripts/doc_gardening.py --check` 强制
- CI 对脚本和测试统一执行

## 阶段 6：垃圾回收与高吞吐
- 定时运行 `housekeeping_scan.sh`
- 将可自动修复的小偏差交给机器人 PR
- PR 生命周期保持短，优先快速合入后续跟进

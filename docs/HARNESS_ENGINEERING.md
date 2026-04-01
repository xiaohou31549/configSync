# Harness Engineering 约定

## 关键文件
- `AGENTS.md`：目录索引，不承载细节大段说明
- `project-progress.txt`：工作班次日志
- `feature_list.json`：稳定结构的功能状态表
- `init.sh`：统一初始化入口

## 智能体工作顺序
1. 看 `git log --oneline -5`
2. 看 `project-progress.txt`
3. 跑 `./init.sh`
4. 读 `feature_list.json`
5. 只做一个最高优先级未通过功能
6. 写验证
7. 实现
8. 更新 `feature_list.json`
9. 追加 `project-progress.txt`
10. 提交 Git Commit

## 为什么使用 JSON 功能表
- 对智能体更稳定
- 适合 CI 做结构化校验
- 便于后续做脚本或仪表盘

## 为什么 macOS 不走浏览器自动化主路径
- 本项目是原生桌面应用，不存在可覆盖主要用户路径的浏览器 UI
- 关键交互都在 SwiftUI 桌面窗口内
- 因此主 E2E 方案是 `XCUITest + 截图 + 可访问性断言`
- 由于 macOS UI 测试依赖签名与 Runner 装载，默认 CI 不阻塞它，使用 `scripts/run_ui_tests.sh` 作为独立入口

## 何时使用浏览器工具
- 验证 GitHub App 安装/授权地址是否生成正确
- 验证未来可能新增的 Web 辅助页
- 抓取 GitHub 文档或接口样例时的辅助观察

# docs 事实来源库

`docs/` 是 SecretSync 的一级工程工件目录。智能体、脚本、CI 和人工维护都应优先读取这里，而不是凭经验猜测仓库约定。

## 文件入口
- `ARCHITECTURE.md`：分层结构、组合根、依赖边界
- `PRODUCT_SPEC.md`：当前产品范围与功能清单
- `EXECUTION_PLAN.md`：Harness 落地路线与分阶段任务
- `HARNESS_ENGINEERING.md`：智能体开发循环、文件职责、自动化约束
- `TESTING_STRATEGY.md`：单元测试、UI 测试、脚本验证与 CI
- `DATABASE_SCHEMA.md`：本地 SQLite、配置文件与会话文件的数据结构约定

## 维护原则
- 文档必须短、准、可执行。
- 会过期的事实尽量由脚本生成或校验。
- 若文档和代码冲突，以代码和测试为准，并立即修文档。

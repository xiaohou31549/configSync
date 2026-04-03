# 本地数据结构

## SQLite：`config_items`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | `TEXT` | 配置项主键，UUID |
| `name` | `TEXT` | 规范化后的配置名 |
| `type` | `TEXT` | `secret` 或 `variable` |
| `description` | `TEXT` | 可选描述 |
| `variable_value` | `TEXT` | 仅 Variable 持久化明文 |
| `created_at` | `REAL` | 创建时间 |
| `updated_at` | `REAL` | 更新时间 |

## Keychain
- `secret.<uuid>`：Secret 的真实值
- `auth.github.appClientSecret`：GitHub App `Client Secret`
- `auth.github.*`：GitHub App 用户令牌、安装访问令牌与会话字段

## 设计原则
- Secret 明文不落 SQLite
- `Client Secret` 不落 `auth.json`，只保存在当前用户 Keychain
- SQLite 负责可查询元数据
- Harness 测试必须使用独立 Keychain service 或 In-Memory 仓库

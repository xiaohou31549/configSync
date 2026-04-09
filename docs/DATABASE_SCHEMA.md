# 本地数据结构

## SQLite：`config_items`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | `TEXT` | 配置项主键，UUID |
| `name` | `TEXT` | 规范化后的配置名 |
| `type` | `TEXT` | `secret` 或 `variable` |
| `description` | `TEXT` | 可选描述 |
| `variable_value` | `TEXT` | 当前用于持久化 Secret 与 Variable 的值；当前 UI 默认不暴露 Variable 编辑，但底层为兼容与后续扩展保留该列 |
| `created_at` | `REAL` | 创建时间 |
| `updated_at` | `REAL` | 更新时间 |

## 本地认证文件
- `auth.json`：GitHub App 覆盖配置，包含 `App ID`、`Client ID`、`Client Secret`、`Slug`、私钥路径与回调地址
- `auth-session.json`：GitHub 用户令牌、刷新令牌、安装列表与 installation token 缓存

## 设计原则
- 当前版本为了消除首次启动的系统钥匙串弹窗，Secret 明文与 GitHub 会话数据都落本地文件或 SQLite
- 用户手工保存的 GitHub App 配置统一保存在 `auth.json`
- 发布包若内置 `BundledGitHubApp.json`，则其 GitHub App 默认配置位于应用包资源，不进入 SQLite
- SQLite 负责可查询元数据
- Harness 测试必须使用独立临时目录或 In-Memory 仓库

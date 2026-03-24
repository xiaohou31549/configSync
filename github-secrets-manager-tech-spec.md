# GitHub Secrets Manager for macOS — 技术方案文档

## 1. 技术目标

构建一个 macOS 原生桌面应用，支持：

- 通过 GitHub App + Device Flow 完成授权登录
- 拉取用户可访问的仓库列表
- 在本地安全管理 Secrets / Variables
- 批量同步到 GitHub Repository Secrets / Variables
- 提供清晰的同步结果与错误反馈

---

## 2. 技术栈建议

## 2.1 客户端
- 语言：Swift 5.10+
- UI：SwiftUI
- 并发：Swift Concurrency（async/await）
- 网络：URLSession
- 本地存储：
  - Keychain：Token / Secret Value
  - SQLite / SwiftData：非敏感元数据
- 日志：OSLog

## 2.2 第三方库建议
### 必选
- libsodium Swift 封装  
  用于 GitHub Secrets 的 sealed box 加密

候选：
- Swift Sodium

### 可选
- KeychainAccess  
  若你不想自己直接封装 Keychain API

说明：  
GitHub Repository Secrets 的写入不是直接传明文，而是需要先获取 repo public key，再使用 libsodium sealed box 在本地加密。

---

## 3. 架构设计

建议采用分层架构：

- Presentation
- Application
- Domain
- Infrastructure

### 3.1 Presentation
负责 UI 展示与用户交互：
- LoginView
- RepositoryListView
- ConfigItemListView
- ConfigEditorView
- SyncResultView

### 3.2 Application
负责用例编排：
- SignInUseCase
- FetchRepositoriesUseCase
- SaveConfigItemUseCase
- SyncConfigItemsUseCase

### 3.3 Domain
负责核心实体和规则：
- Repo
- ConfigItem
- SyncPlan
- SyncResult
- TokenBundle

### 3.4 Infrastructure
负责外部系统访问：
- GitHubAPIClient
- DeviceFlowAuthService
- KeychainStore
- LocalDatabase
- SecretEncryptionService

---

## 4. 模块划分

## 4.1 Auth 模块
职责：
- 发起 Device Flow
- 轮询 access token
- 管理 refresh token
- 处理 token 过期与刷新

核心组件：
- GitHubAuthService
- TokenStore
- AuthStateStore

## 4.2 Repository 模块
职责：
- 拉取 repo 列表
- 搜索和过滤
- 分页加载（如后续需要）

核心组件：
- RepositoryService
- RepositoryViewModel

## 4.3 Config 模块
职责：
- 管理本地 Secrets / Variables
- 保存非敏感元数据
- 将敏感值写入 Keychain

核心组件：
- ConfigRepository
- ConfigEditorViewModel

## 4.4 Sync 模块
职责：
- 拉取目标 repo public key
- 对 Secret 做本地加密
- 调用 GitHub API 写入 Secret / Variable
- 汇总结果

核心组件：
- SyncService
- SecretEncryptionService
- SyncCoordinator

---

## 5. GitHub 授权方案

## 5.1 为什么选 GitHub App + Device Flow
原因：

- 对用户比 PAT 更友好
- 更适合桌面 App
- 权限边界更清晰
- 支持过期 token + refresh token
- 便于未来做成通用工具

## 5.2 授权流程

### 步骤 1：App 请求 Device Flow
客户端请求 GitHub Device Flow 入口，获取：
- device_code
- user_code
- verification_uri
- interval

### 步骤 2：引导用户完成授权
客户端展示 user_code，并打开 GitHub 授权页面。

### 步骤 3：轮询换取用户访问令牌
客户端按 interval 轮询 token 端点。

### 步骤 4：保存 token
将 access token / refresh token 写入 Keychain。

### 步骤 5：拉取用户信息并建立会话
例如拉取：
- 当前用户资料
- 可访问仓库列表

---

## 6. GitHub App 配置建议

## 6.1 GitHub App 类型
创建一个 GitHub App，用于桌面客户端代表用户访问仓库。

## 6.2 需要的权限
按最小权限原则，重点关注：

### Repository permissions
- Secrets：write
- Variables：write
- Metadata：read
- Administration：read（如确有必要）
- Actions：read（仅在需要时）

注意：最终权限名称需以 GitHub App 控制台可选项为准。

## 6.3 用户访问模式
需要支持用户授权后代表其访问其拥有权限的仓库。

---

## 7. GitHub API 设计

## 7.1 仓库列表
使用 GitHub REST API 拉取用户仓库：

- 获取当前用户仓库
- 获取用户可访问仓库
- 支持分页

客户端需要统一封装分页与错误处理。

## 7.2 Repository Secret 写入流程
对每个目标 repo：

1. 请求该 repo 的 public key
2. 使用 libsodium sealed box 加密 secret value
3. 调用 create/update repository secret API

### 伪流程
```text
for repo in selectedRepos:
  publicKey = fetchRepoPublicKey(repo)
  encryptedValue = encrypt(secretValue, publicKey)
  upsertSecret(repo, name, encryptedValue, keyId)
```

## 7.3 Repository Variable 写入流程
Variable 无需本地加密，直接调用 create/update variable API。

---

## 8. 数据存储设计

## 8.1 Keychain 存储内容
- GitHub access token
- GitHub refresh token
- Secret 明文值

Keychain key 命名建议：
- auth.github.accessToken
- auth.github.refreshToken
- secret.<configItemId>

## 8.2 本地数据库存储内容
使用 SwiftData 或 SQLite 存：

### ConfigItemEntity
- id
- name
- type
- description
- createdAt
- updatedAt

### RepoCacheEntity
- id
- fullName
- owner
- visibility
- archived
- fetchedAt

### SyncHistoryEntity（后续）
- id
- startedAt
- endedAt
- successCount
- failureCount

说明：
数据库里不存 Secret 明文。

---

## 9. 领域模型设计

## 9.1 ConfigItem
```swift
enum ConfigItemType {
    case secret
    case variable
}

struct ConfigItem {
    let id: UUID
    var name: String
    var type: ConfigItemType
    var description: String?
    var updatedAt: Date
}
```

## 9.2 Repo
```swift
struct Repo {
    let id: Int
    let name: String
    let fullName: String
    let visibility: Visibility
    let archived: Bool
}
```

## 9.3 SyncRequest
```swift
struct SyncRequest {
    let repos: [Repo]
    let items: [ConfigItem]
    let overwriteExisting: Bool
}
```

## 9.4 SyncResult
```swift
enum SyncStatus {
    case success
    case failed(String)
}

struct SyncResult {
    let repoFullName: String
    let itemName: String
    let status: SyncStatus
}
```

---

## 10. UI 交互方案

## 10.1 登录页
状态：
- 未登录
- 正在授权
- 已登录
- 授权失败

交互：
- 点击登录
- 自动打开浏览器
- 展示 user code
- 轮询中显示进度提示

## 10.2 主页面
采用三栏布局：

### 左栏：Repositories
- 搜索
- 过滤
- 多选
- 全选 / 清空

### 中栏：Config Items
- Secret / Variable 切换
- 搜索
- 新增 / 编辑 / 删除本地项

### 右栏：Editor / Action
- 编辑字段
- Reveal Secret
- Save
- Sync to Selected Repos

## 10.3 同步结果页
- 摘要卡片
- 成功列表
- 失败列表
- 可复制错误详情

---

## 11. 同步引擎设计

## 11.1 执行策略
建议采用“受控并发”：

- 串行处理每个仓库内的多个配置项
- 多个仓库之间限制并发数量，例如 3~5

原因：
- 减少 API 限流风险
- 简化错误归因
- 保证 UI 可跟踪进度

## 11.2 重试策略
对于可恢复错误：
- 429 限流
- 短暂网络失败
- GitHub 5xx

可进行有限重试，例如：
- 最多 3 次
- 指数退避

对于不可恢复错误：
- 401 / 403 权限不足
- repo 不存在
- 用户无权限

直接失败并展示原因。

## 11.3 差异策略
MVP 可不做远端差异比对。  
因为 Secret 无法读取明文，实际只能直接 upsert。  
后续可通过本地签名或同步时间戳优化“跳过未变化项”。

---

## 12. 安全设计

## 12.1 Secret 存储
- Secret value 仅在 Keychain 中保存
- UI 默认 masked
- 日志中绝不打印 value

## 12.2 Token 安全
- access token / refresh token 存 Keychain
- 启动时检查过期
- 需要时自动刷新
- 用户可主动 Sign Out，清空本地凭证

## 12.3 内存安全
- Secret reveal 仅短时间显示
- App 切后台后自动重新 mask
- 避免把 secret 复制到可持久化缓存

## 12.4 本地导出
MVP 不支持导出明文配置。  
如后续支持导出，必须：
- 用户显式确认
- 文件加密
- 附带风险提示

---

## 13. 错误处理

## 13.1 授权类
- 用户未完成授权
- device code 过期
- token 获取失败
- token 刷新失败

## 13.2 GitHub API 类
- repo public key 获取失败
- secret 写入失败
- variable 写入失败
- rate limit exceeded

## 13.3 本地类
- Keychain 保存失败
- 本地数据库读写失败
- libsodium 加密失败

错误需统一映射为：
- 用户可读提示
- 开发调试日志
两层。

---

## 14. 可测试性设计

## 14.1 单元测试
覆盖：
- ConfigItem 规则
- SecretEncryptionService
- SyncService 的错误分支
- Token 刷新逻辑

## 14.2 集成测试
覆盖：
- Device Flow 登录流程（mock）
- 仓库列表拉取
- Secret / Variable 写入流程

## 14.3 UI 测试
覆盖：
- 登录流程
- 新增配置项
- 多选仓库
- 同步结果展示

---

## 15. 代码组织建议

```text
GitHubSecretsManager/
  App/
  Presentation/
    Login/
    Repositories/
    ConfigItems/
    SyncResults/
  Application/
    UseCases/
  Domain/
    Entities/
    Repositories/
    Services/
  Infrastructure/
    GitHubAPI/
    Auth/
    Persistence/
    Security/
  Resources/
  Tests/
```

---

## 16. 里程碑拆解

## Phase 1：基础骨架
- SwiftUI 三栏界面
- 本地 ConfigItem CRUD
- 本地 Keychain 封装
- Repo mock 数据接入

## Phase 2：GitHub 登录
- GitHub App 配置
- Device Flow 接入
- token 存储与刷新

## Phase 3：仓库与同步
- 拉取 repo 列表
- public key 获取
- Secret 加密上传
- Variable 上传

## Phase 4：打磨
- 结果页
- 错误提示
- 并发与重试
- 稳定性优化

---

## 17. 开发建议

### 是否拆两份文档
建议拆成两份：

- PRD：给你自己和 AI 编程工具说明业务目标
- 技术方案：给实现阶段做约束和设计边界

因为一个文档同时承载“业务需求”和“实现细节”时，后续很容易变乱。

### 单人开发的实际策略
虽然只有你一个人开发，但仍建议这样使用：

- PRD 用来驱动功能切分
- 技术方案用来驱动代码结构和任务拆解

这样也更适合后续让 Codex 分阶段开发：
1. 先做登录
2. 再做仓库列表
3. 再做本地配置管理
4. 最后做同步引擎

---

## 18. 结论
本项目最推荐的技术路线是：

- macOS 原生 SwiftUI 客户端
- GitHub App + Device Flow 登录
- Keychain 保存 token 与 secret
- libsodium 完成 repo secret 本地加密
- URLSession + async/await 调用 GitHub REST API
- 分层架构实现，便于 AI 编程工具逐步生成与迭代

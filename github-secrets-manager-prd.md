# GitHub Secrets Manager for macOS — 产品需求文档（PRD）

## 1. 项目概述

### 1.1 项目名称
GitHub Secrets Manager for macOS

### 1.2 项目定位
一个面向开发者的 macOS 桌面工具，用于可视化管理 GitHub Actions 的 Repository Secrets / Variables，并将它们批量同步到多个 GitHub 仓库。

### 1.3 背景与问题
当前在 GitHub 个人账号下，如果有多个仓库共用相似的 CI/CD 配置，例如：

- VPS 部署相关 SSH 配置
- Docker 镜像仓库配置
- Webhook 地址
- 环境标识类变量

开发者通常需要在每个仓库的 Settings → Secrets and variables → Actions 中重复录入。  
这带来几个问题：

- 重复劳动多
- 容易漏配或配错
- 难以统一更新
- 缺少批量管理和可视化状态

本项目希望通过桌面客户端，把“本地维护 + 批量同步 + 可视化选择”这条链路做顺。

---

## 2. 产品目标

### 2.1 核心目标
让用户可以在一个 macOS App 中完成以下操作：

1. 登录 GitHub
2. 拉取可访问的仓库列表
3. 在本地维护一组 Secrets / Variables
4. 选择目标仓库
5. 一键同步到多个 GitHub 仓库
6. 查看同步结果和失败原因

### 2.2 非目标
本期不做：

- GitHub Actions workflow 编辑器
- 云端多端同步
- 团队协作与权限体系
- 仓库代码管理
- 多平台支持（Windows / Web）
- GitHub Enterprise Server 兼容

---

## 3. 目标用户

### 3.1 核心用户
- 个人开发者
- 独立开发者
- 维护多个 GitHub 仓库的 iOS / 前端 / 后端开发者
- 有重复 CI/CD secrets 配置需求的用户

### 3.2 典型用户画像
- 有多个个人仓库
- 经常使用 GitHub Actions
- 需要将多个仓库部署到同一台 VPS 或同一套基础设施
- 希望减少重复配置和手动网页操作

---

## 4. 使用场景

### 场景 1：批量初始化部署配置
用户新建了 5 个仓库，需要全部配置：

- VPS_HOST
- VPS_PORT
- VPS_USER
- VPS_SSH_KEY
- DEPLOY_PATH

用户在 App 中一次录入后，选择 5 个仓库，一键同步。

### 场景 2：统一更新 IP
VPS IP 变更，用户只需要修改本地的 `VPS_HOST`，然后重新同步到所有目标仓库。

### 场景 3：按仓库分组同步
某些仓库属于博客项目，某些属于服务端项目。用户希望按标签或筛选条件选择一组仓库进行同步。

### 场景 4：仅同步 Variables
对于一些非敏感配置，如：

- DEPLOY_PATH
- IMAGE_NAME
- REGION

用户希望作为 Variables 管理，而不是 Secrets。

---

## 5. 功能范围

## 5.1 MVP 功能

### A. GitHub 登录
- 使用 GitHub App + Device Flow 登录
- 用户在浏览器中完成授权
- App 获取访问令牌并安全保存在本地

### B. 仓库列表
- 拉取当前用户可访问的仓库
- 支持搜索仓库
- 支持按 owner / private / public / archived 过滤
- 支持多选仓库

### C. 本地 Secrets 管理
- 新增 Secret
- 编辑 Secret
- 删除本地 Secret
- Secret Value 不明文长期展示
- 支持标记是否为“敏感字段”

### D. 本地 Variables 管理
- 新增 Variable
- 编辑 Variable
- 删除 Variable

### E. 批量同步
- 将选中的 Secrets / Variables 同步到选中的仓库
- 支持覆盖已存在同名配置
- 支持跳过未变化项
- 显示每个仓库的同步结果

### F. 同步结果
- 成功 / 失败数量统计
- 仓库级别结果展示
- 失败原因展示，如：
  - 权限不足
  - API 限流
  - 仓库不可访问
  - Secret 加密失败

---

## 5.2 后续增强功能

### V2
- 删除远端 Secret / Variable
- 同步预览（Dry Run）
- 仓库分组 / 收藏
- 同步历史
- 导入 / 导出本地配置（加密）

### V3
- Environment Secrets / Variables 管理
- 规则模板（例如“VPS 部署模板”）
- GitHub Organization 支持增强
- 多 GitHub 账号切换
- GitHub Enterprise 支持

---

## 6. 核心用户流程

## 6.1 首次使用流程
1. 打开 App
2. 点击“Sign in with GitHub”
3. 使用 Device Flow 完成授权
4. App 拉取仓库列表
5. 用户创建一组 Secrets / Variables
6. 用户选择多个仓库
7. 点击 Sync
8. 查看同步结果

## 6.2 日常更新流程
1. 打开 App
2. 修改已有 Secret 或 Variable
3. 筛选仓库
4. 一键同步
5. 查看结果

---

## 7. 信息架构

## 7.1 页面结构

### 1）登录页
- GitHub 登录按钮
- 授权状态说明
- 错误提示

### 2）主界面
建议采用三栏结构：

#### 左栏：仓库区
- 仓库搜索
- 仓库过滤
- 仓库列表
- 多选

#### 中栏：配置项列表
- Secrets
- Variables
- 搜索配置名
- 类型标识
- 最近修改时间
- 本地是否已变更

#### 右栏：编辑与操作区
- 名称
- 类型（Secret / Variable）
- Value
- 描述（可选）
- 保存按钮
- Sync 按钮
- Dry Run（后续）

### 3）结果面板
- 本次同步摘要
- 成功项
- 失败项
- 失败详情

---

## 8. 数据模型（产品视角）

### 8.1 LocalConfigItem
- id
- name
- type（secret / variable）
- value
- description
- createdAt
- updatedAt

### 8.2 RepoItem
- id
- name
- fullName
- owner
- visibility
- defaultBranch
- archived
- selected

### 8.3 SyncTask
- id
- targetRepos
- configItems
- startedAt
- endedAt
- status
- results

### 8.4 SyncResult
- repoFullName
- itemName
- itemType
- status
- message

---

## 9. 关键产品规则

### 9.1 Secret 与 Variable 区分
- Secret：敏感信息，不允许普通明文长期展示
- Variable：非敏感信息，可普通展示与编辑

### 9.2 Value 展示规则
- Secret 默认遮挡
- 用户主动点击 reveal 后临时可见
- App 切到后台或锁屏后自动重新遮挡

### 9.3 覆盖规则
- 默认覆盖同名远端配置
- 后续可增加“仅新增不覆盖”模式

### 9.4 删除规则
MVP 不做远端删除，避免误删；仅支持本地删除。

---

## 10. 权限与安全要求

### 10.1 登录
采用 GitHub App + Device Flow，不要求用户手动创建 PAT。

### 10.2 本地存储
- 访问令牌存储于 macOS Keychain
- Refresh Token 存储于 macOS Keychain
- Secret Value 优先存储于 macOS Keychain
- 非敏感元数据可存本地数据库

### 10.3 日志
- 不记录 Secret 明文
- 不记录 Token 明文
- 错误日志需脱敏

### 10.4 网络传输
- 仅通过 HTTPS 调用 GitHub API
- Secret 加密在本地完成后再上传

---

## 11. 成功指标

### MVP 验收标准
- 用户可成功登录 GitHub
- 可拉取仓库列表
- 可新增本地 Secret / Variable
- 可选择多个仓库进行同步
- 至少 90% 正常 API 场景下同步成功
- 同步失败时有明确错误提示
- 本地不出现 Secret 明文日志泄漏

### 使用层指标（后续观察）
- 单次批量同步耗时
- 单次同步平均仓库数
- 同步成功率
- 用户重复打开率

---

## 12. 风险与边界

### 风险 1：GitHub API 限流
需要做节流、重试与错误提示。

### 风险 2：权限不足
某些仓库用户没有 admin / actions 相关权限，会导致写入失败。

### 风险 3：用户误以为可读回 Secret 明文
GitHub Secret 不可反查明文，产品交互上必须明确。

### 风险 4：Secret 本地存储设计不当
需要严格依赖 Keychain，避免落盘明文。

---

## 13. 里程碑建议

### Milestone 1：MVP
- GitHub 登录
- 仓库列表
- 本地 Secrets / Variables 管理
- 批量同步
- 基础结果展示

### Milestone 2：增强版
- Dry Run
- 同步历史
- 失败重试
- 仓库分组

### Milestone 3：进阶版
- Environment 管理
- 多账号
- 模板化同步

---

## 14. 结论
对单人开发来说，建议仍然拆成两份文档：

- 一份 PRD：明确“做什么”
- 一份技术方案：明确“怎么做”

原因不是流程复杂，而是这个项目同时包含：

- GitHub 授权
- Keychain 安全存储
- 本地数据模型
- GitHub Secret 加密上传
- 批量同步与错误处理

拆开后更利于你后面交给 Codex / AI 编程工具逐步实现。

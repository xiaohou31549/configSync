# 产品规格

## 产品定位
SecretSync 是一个 macOS 原生桌面工具，用于本地维护 GitHub Actions 的 Secrets，并将其批量同步到多个 GitHub 仓库。

## 当前范围
- GitHub App 安装、用户授权与会话恢复
- 拉取用户可访问仓库
- 本地维护 Secret
- 按仓库搜索、筛选、多选
- 批量同步并展示结果
- GitHub App 本地配置保存，其中 `Client Secret` 存入 Keychain，其余元数据保存在本地配置文件

## 非目标
- 第一版不做从 GitHub 仓库导入 Secret
- 第一版不做 Variable 管理
- GitHub Workflow 编辑
- 云端多端同步
- 团队协作
- Web / Windows 客户端
- GitHub Enterprise 适配

## 功能清单来源
- 历史 PRD：`github-secrets-manager-prd.md`
- 当前可执行状态：`feature_list.json`

## 当前优先级原则
1. 先保证 GitHub App 安装授权、本地配置、仓库选择、同步链路可用
2. 再补充可重复验证、观测和回归防线
3. 最后考虑增强能力，如导入导出、Dry Run、历史记录

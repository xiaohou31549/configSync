import SwiftUI

public struct ConfigItemsView: View {
    @ObservedObject var viewModel: AppViewModel

    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("本地 Secret")
                    .font(.title2.bold())
                Spacer()
                Button(viewModel.isAuthenticated ? "同步到选中仓库" : "登录 GitHub 后同步") {
                    if viewModel.isAuthenticated {
                        viewModel.syncSelected()
                    } else {
                        viewModel.signIn()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isSyncing || viewModel.filteredConfigItems.isEmpty)
                .accessibilityIdentifier("config.syncButton")

                Button("新增 Secret") {
                    viewModel.createNewDraft()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("config.newButton")
            }

            TextField("搜索 Secret 名称或描述", text: $viewModel.configSearchText)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("config.searchField")

            if viewModel.filteredConfigItems.isEmpty {
                GroupBox("先创建第一条本地 Secret") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("第一版 MVP 只支持在应用内本地创建、编辑和删除 Secret。准备同步时，再登录 GitHub 选择目标仓库。")
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Button("新建空白 Secret") {
                            viewModel.createNewDraft()
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("config.blankDraftButton")
                    }
                }

                Spacer(minLength: 0)
            } else {
                List(viewModel.filteredConfigItems, selection: $viewModel.selectedConfigItemID) { item in
                    Button {
                        viewModel.selectConfigItem(item)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.name)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("Secret")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(.red.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                            if let description = item.description, !description.isEmpty {
                                Text(description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(item.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("config.list")
            }

            GroupBox("同步状态") {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("覆盖已存在同名配置", isOn: $viewModel.overwriteExisting)
                        .accessibilityIdentifier("config.overwriteToggle")

                    Text("同步范围：已选仓库 \(viewModel.selectedRepoIDs.count) 个；Secret \(viewModel.selectedItemsForSync.count) 个。未单独打开某条 Secret 时，会同步当前列表中过滤后的全部本地 Secret。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if !viewModel.isAuthenticated {
                        HStack(spacing: 12) {
                            Button("登录 GitHub") {
                                viewModel.signIn()
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("config.loginButton")

                            Button(viewModel.isUsingBundledGitHubAppConfiguration ? "高级配置" : "配置 GitHub App") {
                                viewModel.loadAuthSettings()
                                viewModel.showAuthSettings = true
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("config.githubAppSettingsButton")
                        }

                        Text(viewModel.isUsingBundledGitHubAppConfiguration
                             ? "当前发布包已内置 GitHub 连接配置。你可以先维护本地 Secret，准备同步时直接完成 GitHub 授权。"
                             : "当前还未登录 GitHub。你可以先维护本地 Secret，准备同步时再完成 GitHub 授权。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let summary = viewModel.syncSummary {
                SyncResultsPanel(summary: summary)
            }

            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("config.panel")
    }
}

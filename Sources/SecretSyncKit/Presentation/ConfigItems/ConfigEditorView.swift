import SwiftUI

public struct ConfigEditorView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var revealSecret = false

    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if !viewModel.isAuthenticated {
                    LoginView(viewModel: viewModel)
                        .padding(.bottom, 4)
                }

                HStack {
                    Text("编辑器")
                        .font(.title2.bold())
                    Spacer()
                    if viewModel.isRefreshing || viewModel.isSaving || viewModel.isSyncing {
                        ProgressView()
                    }
                }

                GroupBox("配置详情") {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("名称，例如 VPS_HOST", text: $viewModel.draft.name)
                            .textFieldStyle(.roundedBorder)

                        Picker("类型", selection: $viewModel.draft.type) {
                            ForEach(ConfigItemType.allCases) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)

                        if viewModel.draft.type == .secret && !revealSecret {
                            SecureField("Secret Value", text: $viewModel.draft.value)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            TextField("Value", text: $viewModel.draft.value, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(3...8)
                        }

                        if viewModel.draft.type == .secret {
                            Toggle("显示 Secret 明文", isOn: $revealSecret)
                        }

                        TextField("描述（可选）", text: $viewModel.draft.description, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)
                    }
                }

                GroupBox("同步操作") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("覆盖已存在同名配置", isOn: $viewModel.overwriteExisting)
                        Text("同步范围：已选仓库 \(viewModel.selectedRepoIDs.count) 个；配置项 \(viewModel.selectedItemsForSync.count) 个。未在中栏选中具体项时，会同步当前类型筛选下的全部可见项。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        if !viewModel.isAuthenticated {
                            Text("当前还未登录 GitHub。你可以先保存本地配置；当你准备读取仓库或开始同步时，再点击右侧按钮完成授权。")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Button("保存") {
                                viewModel.saveDraft()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(viewModel.isSaving)

                            Button("删除") {
                                viewModel.deleteSelectedItem()
                            }
                            .disabled(viewModel.selectedConfigItemID == nil)

                            Spacer()

                            Button(viewModel.isAuthenticated ? "同步到选中仓库" : "登录 GitHub 后同步") {
                                if viewModel.isAuthenticated {
                                    viewModel.syncSelected()
                                } else {
                                    viewModel.signIn()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(viewModel.isSyncing)
                        }
                    }
                }

                if let summary = viewModel.syncSummary {
                    SyncResultsPanel(summary: summary)
                }
            }
            .padding()
        }
    }
}

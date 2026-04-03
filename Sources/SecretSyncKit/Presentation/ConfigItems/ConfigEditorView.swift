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
                HStack {
                    Text(viewModel.isEditingExistingConfigItem ? "编辑 Secret" : "新增 Secret")
                        .font(.title2.bold())
                    Spacer()
                    if viewModel.isRefreshing || viewModel.isSaving || viewModel.isSyncing {
                        ProgressView()
                    }
                }

                GroupBox("配置详情") {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Secret 名称，例如 VPS_HOST", text: $viewModel.draft.name)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("editor.nameField")

                        if !revealSecret && !viewModel.shouldUsePlaintextSecretEditorForAutomation {
                            SecureField("Secret Value", text: $viewModel.draft.value)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityIdentifier("editor.secretValueField")
                        } else {
                            TextField("Value", text: $viewModel.draft.value, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(3...8)
                                .accessibilityIdentifier("editor.valueField")
                        }

                        Toggle("显示 Secret 明文", isOn: $revealSecret)
                            .accessibilityIdentifier("editor.revealSecretToggle")

                        TextField("描述（可选）", text: $viewModel.draft.description, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)
                            .accessibilityIdentifier("editor.descriptionField")
                    }
                }

                GroupBox("同步操作") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("覆盖已存在同名配置", isOn: $viewModel.overwriteExisting)

                        Text("同步范围：已选仓库 \(viewModel.selectedRepoIDs.count) 个；配置项 \(viewModel.selectedItemsForSync.count) 个。未在中栏选中具体项时，会同步当前类型筛选下的全部可见项。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Text(viewModel.syncReadiness.message)
                            .font(.footnote)
                            .foregroundStyle(viewModel.canSyncSelection ? Color.secondary : Color.orange)

                        Button(viewModel.isAuthenticated ? "同步到选中仓库" : "登录 GitHub 后同步") {
                            viewModel.syncSelected()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!viewModel.canSyncSelection)
                        .accessibilityIdentifier("editor.syncButton")
                    }
                }

                HStack {
                    Button("取消") {
                        viewModel.dismissConfigEditor()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("editor.cancelButton")

                    Spacer()

                    if viewModel.isEditingExistingConfigItem {
                        Button("删除") {
                            viewModel.deleteSelectedItem()
                        }
                        .disabled(viewModel.selectedConfigItemID == nil)
                        .accessibilityIdentifier("editor.deleteButton")
                    }

                    Button("保存") {
                        viewModel.saveDraft()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isSaving)
                    .accessibilityIdentifier("editor.saveButton")
                }

                Spacer(minLength: 0)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("editor.panel")
    }
}

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

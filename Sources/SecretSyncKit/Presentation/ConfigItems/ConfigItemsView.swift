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
                Button("新增 Secret") {
                    viewModel.createNewDraft()
                }
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

            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("config.panel")
    }
}

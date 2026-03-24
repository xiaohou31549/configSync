import SwiftUI

public struct ConfigItemsView: View {
    @ObservedObject var viewModel: AppViewModel

    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Config Items")
                    .font(.title2.bold())
                Spacer()
                Button("新增") {
                    viewModel.createNewDraft()
                }
            }

            Picker("类型", selection: $viewModel.configTypeFilter) {
                ForEach(ConfigItemType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)

            TextField("搜索配置名或描述", text: $viewModel.configSearchText)
                .textFieldStyle(.roundedBorder)

            List(viewModel.filteredConfigItems, selection: $viewModel.selectedConfigItemID) { item in
                Button {
                    viewModel.selectConfigItem(item)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.name)
                                .fontWeight(.medium)
                            Spacer()
                            Text(item.type.displayName)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(item.type == .secret ? .red.opacity(0.12) : .blue.opacity(0.12))
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
        }
        .padding()
    }
}

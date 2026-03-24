import SwiftUI

public struct RepositoryListView: View {
    @ObservedObject var viewModel: AppViewModel

    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Repositories")
                .font(.title2.bold())

            TextField("搜索仓库或 owner", text: $viewModel.repoSearchText)
                .textFieldStyle(.roundedBorder)

            Picker("可见性", selection: $viewModel.repoVisibilityFilter) {
                Text("全部").tag(RepoVisibility.all)
                Text("Public").tag(RepoVisibility.public)
                Text("Private").tag(RepoVisibility.private)
            }
            .pickerStyle(.segmented)

            Toggle("显示已归档仓库", isOn: $viewModel.showArchivedRepositories)

            HStack {
                Button("全选可见项") {
                    viewModel.selectAllVisibleRepositories()
                }
                Button("清空") {
                    viewModel.clearRepositorySelection()
                }
            }

            List(viewModel.filteredRepositories) { repo in
                Button {
                    viewModel.toggleRepositorySelection(repo.id)
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: viewModel.selectedRepoIDs.contains(repo.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(viewModel.selectedRepoIDs.contains(repo.id) ? .green : .secondary)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(repo.fullName)
                                if repo.archived {
                                    Label("Archived", systemImage: "archivebox")
                                        .labelStyle(.titleAndIcon)
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                            Text("\(repo.visibility.rawValue.capitalized) · \(repo.defaultBranch)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Text("已选 \(viewModel.selectedRepoIDs.count) 个仓库")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

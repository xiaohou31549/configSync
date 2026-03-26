import SwiftUI

public struct RepositoryListView: View {
    @ObservedObject var viewModel: AppViewModel

    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("目标仓库")
                    .font(.title2.bold())
                Spacer()
                if viewModel.isAuthenticated {
                    Button("退出登录") {
                        viewModel.signOut()
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("登录 GitHub") {
                        viewModel.signIn()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            if viewModel.isAuthenticated {
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Text("已选 \(viewModel.selectedRepoIDs.count) 个仓库")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                GroupBox("先体验本地配置，准备同步时再登录") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("你现在可以先在中间和右侧创建 Secret / Variable。本应用只会在你需要加载 GitHub 仓库或执行同步时请求授权。")
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(alignment: .leading, spacing: 8) {
                            Label("本地编辑配置项", systemImage: "square.and.pencil")
                            Label("选择目标仓库并批量同步", systemImage: "shippingbox")
                            Label("Secret 明文仅保存在本地，上传前会加密", systemImage: "lock.shield")
                        }
                        .font(.footnote)

                        Button("登录 GitHub 以加载仓库") {
                            viewModel.signIn()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                Spacer()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

import SwiftUI

public struct RootView: View {
    @StateObject private var viewModel: AppViewModel

    public init(container: AppContainer) {
        _viewModel = StateObject(wrappedValue: AppViewModel(container: container))
    }

    public var body: some View {
        Group {
            if viewModel.session == nil {
                LoginView(viewModel: viewModel)
            } else {
                MainDashboardView(viewModel: viewModel)
            }
        }
        .frame(minWidth: 1180, minHeight: 760)
        .task {
            await viewModel.restoreSession()
        }
        .alert("提示", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

private struct MainDashboardView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        NavigationSplitView {
            RepositoryListView(viewModel: viewModel)
        } content: {
            ConfigItemsView(viewModel: viewModel)
        } detail: {
            ConfigEditorView(viewModel: viewModel)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("退出登录") {
                    viewModel.signOut()
                }
            }
        }
    }
}

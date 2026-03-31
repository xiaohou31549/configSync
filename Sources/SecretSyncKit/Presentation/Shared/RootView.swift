import SwiftUI

public struct RootView: View {
    @StateObject private var viewModel: AppViewModel
    private let container: AppContainer

    public init(container: AppContainer) {
        self.container = container
        _viewModel = StateObject(wrappedValue: AppViewModel(container: container))
    }

    public var body: some View {
        MainDashboardView(viewModel: viewModel)
        .frame(minWidth: 1180, minHeight: 760)
        #if canImport(AppKit)
        .background(
            WindowChromeConfigurator()
                .frame(width: 0, height: 0)
        )
        #endif
        .task {
            guard container.shouldRestoreSessionOnLaunch else { return }
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
        HSplitView {
            RepositoryListView(viewModel: viewModel)
                .frame(minWidth: 300, idealWidth: 340, maxWidth: 380, maxHeight: .infinity)

            ConfigItemsView(viewModel: viewModel)
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 360, maxHeight: .infinity)

            ConfigEditorView(viewModel: viewModel)
                .frame(minWidth: 540, idealWidth: 720, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("root.dashboard")
    }
}

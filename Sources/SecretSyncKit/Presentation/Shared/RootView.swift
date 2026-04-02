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
        .frame(minWidth: 980, minHeight: 760)
        #if canImport(AppKit)
        .background(
            WindowChromeConfigurator()
                .frame(width: 0, height: 0)
        )
        #endif
        .task {
            await viewModel.loadInitialState(restoreSession: container.shouldRestoreSessionOnLaunch)
        }
        .alert("提示", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(isPresented: $viewModel.showConfigEditor) {
            NavigationStack {
                ConfigEditorView(viewModel: viewModel)
                    .navigationTitle(viewModel.isEditingExistingConfigItem ? "编辑 Secret" : "新增 Secret")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("关闭") {
                                viewModel.dismissConfigEditor()
                            }
                        }
                    }
            }
            .frame(minWidth: 560, minHeight: 560)
        }
        .sheet(isPresented: $viewModel.showAuthSettings) {
            AuthSettingsSheet(viewModel: viewModel)
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
                .frame(minWidth: 520, idealWidth: 760, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("root.dashboard")
    }
}

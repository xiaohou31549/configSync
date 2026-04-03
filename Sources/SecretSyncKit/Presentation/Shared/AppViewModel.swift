import Foundation
import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

public enum SyncReadiness: Equatable, Sendable {
    case ready
    case requiresAuthentication
    case requiresRepositorySelection
    case requiresConfigSelection

    public var message: String {
        switch self {
        case .ready:
            "可以开始同步到选中仓库"
        case .requiresAuthentication:
            "同步前需要先登录 GitHub"
        case .requiresRepositorySelection:
            "同步前至少选择一个仓库"
        case .requiresConfigSelection:
            "同步前至少选择一个配置项"
        }
    }
}

@MainActor
public final class AppViewModel: ObservableObject {
    @Published public private(set) var session: UserSession?
    @Published public private(set) var repositories: [Repo] = []
    @Published public private(set) var configItems: [ConfigItem] = []
    @Published public var selectedRepoIDs: Set<Int> = []
    @Published public var selectedConfigItemID: UUID?
    @Published public var repoSearchText = ""
    @Published public var configSearchText = ""
    @Published public var repoVisibilityFilter: RepoVisibility = .all
    @Published public var showArchivedRepositories = false
    @Published public var configTypeFilter: ConfigItemType = .secret
    @Published public var draft = ConfigItemDraft()
    @Published public var showConfigEditor = false
    @Published public var isSigningIn = false
    @Published public var isRefreshing = false
    @Published public var isSaving = false
    @Published public var isSyncing = false
    @Published public var overwriteExisting = true
    @Published public var syncSummary: SyncSummary?
    @Published public var errorMessage: String?
    @Published public var authProgressMessage: String?
    @Published public var authorizationURL: URL?
    @Published public var showAuthSettings = false
    @Published public var authSettingsDraft = GitHubAuthSettingsDraft()
    @Published public var authSettingsLocation = ""
    @Published public var hasSavedGitHubAppConfiguration = false
    @Published public var isSavingAuthSettings = false

    private let container: AppContainer

    public init(container: AppContainer) {
        self.container = container
    }

    public var filteredRepositories: [Repo] {
        repositories.filter { repo in
            let searchText = repoSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let matchesSearch = searchText.isEmpty ||
                repo.fullName.lowercased().contains(searchText) ||
                repo.owner.lowercased().contains(searchText)
            let matchesVisibility = repoVisibilityFilter == .all || repo.visibility == repoVisibilityFilter
            let matchesArchived = showArchivedRepositories || !repo.archived
            return matchesSearch && matchesVisibility && matchesArchived
        }
    }

    public var filteredConfigItems: [ConfigItem] {
        configItems.filter { item in
            let searchText = configSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let matchesType = item.type == configTypeFilter
            let matchesSearch = searchText.isEmpty ||
                item.name.lowercased().contains(searchText) ||
                (item.description?.lowercased().contains(searchText) ?? false)
            return matchesType && matchesSearch
        }
    }

    public var selectedRepos: [Repo] {
        repositories.filter { selectedRepoIDs.contains($0.id) }
    }

    public var selectedItemsForSync: [ConfigItem] {
        if showConfigEditor,
           let selectedConfigItemID,
           let item = configItems.first(where: { $0.id == selectedConfigItemID }) {
            return [item]
        }
        return filteredConfigItems
    }

    public var isAuthenticated: Bool {
        session != nil
    }

    public var hasConfigItems: Bool {
        !configItems.isEmpty
    }

    public var syncReadiness: SyncReadiness {
        if !isAuthenticated {
            return .requiresAuthentication
        }

        if selectedRepos.isEmpty {
            return .requiresRepositorySelection
        }

        if selectedItemsForSync.isEmpty {
            return .requiresConfigSelection
        }

        return .ready
    }

    public var canSyncSelection: Bool {
        syncReadiness == .ready && !isSyncing
    }

    public var shouldUsePlaintextSecretEditorForAutomation: Bool {
        container.shouldUsePlaintextSecretEditorForAutomation
    }

    public var isEditingExistingConfigItem: Bool {
        selectedConfigItemID != nil
    }

    public func loadInitialState(restoreSession: Bool) async {
        loadAuthSettings()

        do {
            configItems = try await container.loadConfigItemsUseCase.execute()
            if let selected = selectedConfigItemID,
               let item = configItems.first(where: { $0.id == selected }) {
                selectConfigItem(item, presentEditor: false)
            } else {
                createNewDraft(presentEditor: false)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        guard restoreSession else { return }

        do {
            session = try await container.signInUseCase.restoreSession()
            if session != nil {
                repositories = try await container.fetchRepositoriesUseCase.execute()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func signIn() {
        isSigningIn = true
        errorMessage = nil
        authProgressMessage = nil
        authorizationURL = nil

        Task {
            defer { isSigningIn = false }

            do {
                session = try await container.signInUseCase.execute { [weak self] progress in
                    await MainActor.run {
                        self?.authProgressMessage = progress.message
                        if case let .openingBrowser(url) = progress {
                            self?.authorizationURL = url
                            if self?.container.shouldOpenAuthorizationURL == true {
                                self?.openVerificationURL()
                            }
                        }
                    }
                }
                authProgressMessage = "登录成功"
                await refreshAll()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    public func restoreSession() async {
        await loadInitialState(restoreSession: true)
    }

    public func signOut() {
        Task {
            do {
                try await container.signInUseCase.signOut()
                session = nil
                repositories = []
                configItems = []
                selectedRepoIDs = []
                selectedConfigItemID = nil
                syncSummary = nil
                authProgressMessage = nil
                authorizationURL = nil
                createNewDraft(presentEditor: false)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    public func refreshAll() async {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            async let repos = container.fetchRepositoriesUseCase.execute()
            async let items = container.loadConfigItemsUseCase.execute()
            repositories = try await repos
            configItems = try await items

            if let selected = selectedConfigItemID, let item = configItems.first(where: { $0.id == selected }) {
                selectConfigItem(item, presentEditor: false)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func createNewDraft(presentEditor: Bool = true) {
        selectedConfigItemID = nil
        draft = ConfigItemDraft(type: .secret)
        showConfigEditor = presentEditor
    }

    public func selectConfigItem(_ item: ConfigItem, presentEditor: Bool = true) {
        selectedConfigItemID = item.id
        draft = ConfigItemDraft(
            id: item.id,
            name: item.name,
            type: item.type,
            value: item.value,
            description: item.description ?? ""
        )
        showConfigEditor = presentEditor
    }

    public func dismissConfigEditor() {
        showConfigEditor = false
    }

    public func saveDraft() {
        isSaving = true
        errorMessage = nil

        Task {
            defer { isSaving = false }

            do {
                let saved = try await container.saveConfigItemUseCase.execute(draft)
                configItems = try await container.loadConfigItemsUseCase.execute()
                selectedConfigItemID = saved.id
                selectConfigItem(saved, presentEditor: false)
                showConfigEditor = false
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    public func deleteSelectedItem() {
        guard let selectedConfigItemID else { return }

        Task {
            do {
                try await container.deleteConfigItemUseCase.execute(id: selectedConfigItemID)
                configItems = try await container.loadConfigItemsUseCase.execute()
                showConfigEditor = false
                if let next = filteredConfigItems.first {
                    selectConfigItem(next, presentEditor: false)
                } else {
                    createNewDraft(presentEditor: false)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    public func toggleRepositorySelection(_ repoID: Int) {
        if selectedRepoIDs.contains(repoID) {
            selectedRepoIDs.remove(repoID)
        } else {
            selectedRepoIDs.insert(repoID)
        }
    }

    public func selectAllVisibleRepositories() {
        selectedRepoIDs.formUnion(filteredRepositories.map(\.id))
    }

    public func clearRepositorySelection() {
        selectedRepoIDs.removeAll()
    }

    public func syncSelected() {
        guard syncReadiness == .ready else {
            authProgressMessage = syncReadiness.message
            return
        }

        isSyncing = true
        errorMessage = nil
        syncSummary = nil

        Task {
            defer { isSyncing = false }

            do {
                syncSummary = try await container.syncConfigItemsUseCase.execute(
                    repos: selectedRepos,
                    items: selectedItemsForSync,
                    overwriteExisting: overwriteExisting
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    public func openVerificationURL() {
#if canImport(AppKit)
        guard let url = authorizationURL else { return }
        NSWorkspace.shared.open(url)
#endif
    }

    public func loadAuthSettings() {
        do {
            authSettingsDraft = try container.authSettingsStore.loadDraft() ?? GitHubAuthSettingsDraft()
            authSettingsLocation = try container.authSettingsStore.settingsLocation().path()
            hasSavedGitHubAppConfiguration = authSettingsDraft.isValid
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func saveAuthSettings() {
        isSavingAuthSettings = true
        errorMessage = nil

        Task {
            defer { isSavingAuthSettings = false }

            do {
                try container.authSettingsStore.saveDraft(authSettingsDraft)
                loadAuthSettings()
                authProgressMessage = "GitHub App 配置已保存，Client Secret 已写入 Keychain"
                showAuthSettings = false
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    public func clearAuthSettings() {
        do {
            try container.authSettingsStore.removeDraft()
            authSettingsDraft = GitHubAuthSettingsDraft()
            hasSavedGitHubAppConfiguration = false
            authProgressMessage = "已清除本地 GitHub App 配置，并从 Keychain 删除 Client Secret"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

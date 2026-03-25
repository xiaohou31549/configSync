import Foundation
import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

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
    @Published public var hasSavedOAuthConfiguration = false
    @Published public var isSavingAuthSettings = false

    private let container: AppContainer

    public init(container: AppContainer) {
        self.container = container
    }

    public var filteredRepositories: [Repo] {
        repositories.filter { repo in
            let matchesSearch = repoSearchText.isEmpty ||
                repo.fullName.localizedCaseInsensitiveContains(repoSearchText) ||
                repo.owner.localizedCaseInsensitiveContains(repoSearchText)
            let matchesVisibility = repoVisibilityFilter == .all || repo.visibility == repoVisibilityFilter
            let matchesArchived = showArchivedRepositories || !repo.archived
            return matchesSearch && matchesVisibility && matchesArchived
        }
    }

    public var filteredConfigItems: [ConfigItem] {
        configItems.filter { item in
            let matchesType = item.type == configTypeFilter
            let matchesSearch = configSearchText.isEmpty ||
                item.name.localizedCaseInsensitiveContains(configSearchText) ||
                (item.description?.localizedCaseInsensitiveContains(configSearchText) ?? false)
            return matchesType && matchesSearch
        }
    }

    public var selectedRepos: [Repo] {
        repositories.filter { selectedRepoIDs.contains($0.id) }
    }

    public var selectedItemsForSync: [ConfigItem] {
        if let selectedConfigItemID, let item = configItems.first(where: { $0.id == selectedConfigItemID }) {
            return [item]
        }
        return filteredConfigItems
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
                            self?.openVerificationURL()
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
        loadAuthSettings()
        do {
            session = try await container.signInUseCase.restoreSession()
            if session != nil {
                await refreshAll()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
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
                createNewDraft()
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

            if selectedConfigItemID == nil {
                selectedConfigItemID = filteredConfigItems.first?.id
            }

            if let selected = selectedConfigItemID, let item = configItems.first(where: { $0.id == selected }) {
                draft = ConfigItemDraft(
                    id: item.id,
                    name: item.name,
                    type: item.type,
                    value: item.value,
                    description: item.description ?? ""
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func createNewDraft() {
        selectedConfigItemID = nil
        draft = ConfigItemDraft(type: configTypeFilter)
    }

    public func selectConfigItem(_ item: ConfigItem) {
        selectedConfigItemID = item.id
        draft = ConfigItemDraft(
            id: item.id,
            name: item.name,
            type: item.type,
            value: item.value,
            description: item.description ?? ""
        )
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
                selectConfigItem(saved)
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
                if let next = filteredConfigItems.first {
                    selectConfigItem(next)
                } else {
                    createNewDraft()
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
            hasSavedOAuthConfiguration = authSettingsDraft.isValid
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
                authProgressMessage = "OAuth 配置已保存，可以直接重新点击登录"
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
            hasSavedOAuthConfiguration = false
            authProgressMessage = "已清除本地 OAuth 配置，当前会回退到 mock 登录"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

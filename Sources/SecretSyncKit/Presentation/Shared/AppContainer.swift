import Foundation

public struct AppContainer: Sendable {
    public let signInUseCase: SignInUseCase
    public let fetchRepositoriesUseCase: FetchRepositoriesUseCase
    public let loadConfigItemsUseCase: LoadConfigItemsUseCase
    public let saveConfigItemUseCase: SaveConfigItemUseCase
    public let deleteConfigItemUseCase: DeleteConfigItemUseCase
    public let syncConfigItemsUseCase: SyncConfigItemsUseCase
    public let authSettingsStore: any AuthSettingsStore
    public let authConfigurationLoader: GitHubAuthConfigurationLoader
    public let shouldRestoreSessionOnLaunch: Bool
    public let shouldOpenAuthorizationURL: Bool
    public let shouldUsePlaintextSecretEditorForAutomation: Bool

    public init(
        signInUseCase: SignInUseCase,
        fetchRepositoriesUseCase: FetchRepositoriesUseCase,
        loadConfigItemsUseCase: LoadConfigItemsUseCase,
        saveConfigItemUseCase: SaveConfigItemUseCase,
        deleteConfigItemUseCase: DeleteConfigItemUseCase,
        syncConfigItemsUseCase: SyncConfigItemsUseCase,
        authSettingsStore: any AuthSettingsStore,
        authConfigurationLoader: GitHubAuthConfigurationLoader = GitHubAuthConfigurationLoader(),
        shouldRestoreSessionOnLaunch: Bool,
        shouldOpenAuthorizationURL: Bool = true,
        shouldUsePlaintextSecretEditorForAutomation: Bool = false
    ) {
        self.signInUseCase = signInUseCase
        self.fetchRepositoriesUseCase = fetchRepositoriesUseCase
        self.loadConfigItemsUseCase = loadConfigItemsUseCase
        self.saveConfigItemUseCase = saveConfigItemUseCase
        self.deleteConfigItemUseCase = deleteConfigItemUseCase
        self.syncConfigItemsUseCase = syncConfigItemsUseCase
        self.authSettingsStore = authSettingsStore
        self.authConfigurationLoader = authConfigurationLoader
        self.shouldRestoreSessionOnLaunch = shouldRestoreSessionOnLaunch
        self.shouldOpenAuthorizationURL = shouldOpenAuthorizationURL
        self.shouldUsePlaintextSecretEditorForAutomation = shouldUsePlaintextSecretEditorForAutomation
    }

    public static func bootstrap() -> AppContainer {
        let runtime = HarnessRuntime.current()
        let configRepository: any ConfigRepository

        if runtime.useInMemoryStore {
            configRepository = InMemoryConfigRepository()
        } else if let databaseURL = runtime.databaseURL {
            configRepository = (try? SQLiteConfigRepository(databaseURL: databaseURL)) ?? InMemoryConfigRepository()
        } else {
            configRepository = (try? SQLiteConfigRepository.makeDefault()) ?? InMemoryConfigRepository()
        }

        let authSettingsStore = FileAuthSettingsStore(
            baseDirectoryOverride: runtime.authSettingsDirectory
        )
        let configurationLoader = GitHubAuthConfigurationLoader(
            baseDirectoryOverride: runtime.authSettingsDirectory
        )
        let authRepository = GitHubAuthRepository(
            configurationLoader: configurationLoader,
            sessionStore: FileAuthSessionStore(
                stateURL: runtime.authSettingsDirectory?.appending(path: "auth-session.json")
            )
        )
        let repositoryCatalog = GitHubRepositoryCatalog(
            client: GitHubAPIClient(authRepository: authRepository)
        )
        let syncExecutor = GitHubSyncExecutor(
            client: GitHubActionsAPIClient(authRepository: authRepository),
            encryptionService: GitHubSecretEncryptionService()
        )

        return AppContainer(
            signInUseCase: SignInUseCase(authRepository: authRepository),
            fetchRepositoriesUseCase: FetchRepositoriesUseCase(repositoryCatalog: repositoryCatalog),
            loadConfigItemsUseCase: LoadConfigItemsUseCase(configRepository: configRepository),
            saveConfigItemUseCase: SaveConfigItemUseCase(configRepository: configRepository),
            deleteConfigItemUseCase: DeleteConfigItemUseCase(configRepository: configRepository),
            syncConfigItemsUseCase: SyncConfigItemsUseCase(syncExecutor: syncExecutor),
            authSettingsStore: authSettingsStore,
            authConfigurationLoader: configurationLoader,
            shouldRestoreSessionOnLaunch: !runtime.skipSessionRestore,
            shouldOpenAuthorizationURL: !runtime.isEnabled,
            shouldUsePlaintextSecretEditorForAutomation: runtime.isEnabled
        )
    }
}

import Foundation

public struct AppContainer: Sendable {
    public let signInUseCase: SignInUseCase
    public let fetchRepositoriesUseCase: FetchRepositoriesUseCase
    public let loadConfigItemsUseCase: LoadConfigItemsUseCase
    public let saveConfigItemUseCase: SaveConfigItemUseCase
    public let deleteConfigItemUseCase: DeleteConfigItemUseCase
    public let syncConfigItemsUseCase: SyncConfigItemsUseCase
    public let authSettingsStore: any AuthSettingsStore
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
        self.shouldRestoreSessionOnLaunch = shouldRestoreSessionOnLaunch
        self.shouldOpenAuthorizationURL = shouldOpenAuthorizationURL
        self.shouldUsePlaintextSecretEditorForAutomation = shouldUsePlaintextSecretEditorForAutomation
    }

    public static func bootstrap() -> AppContainer {
        let runtime = HarnessRuntime.current()
        let keychainStore = KeychainStore(service: runtime.keychainService)
        let configRepository: any ConfigRepository

        if runtime.useInMemoryStore {
            configRepository = InMemoryConfigRepository()
        } else if let databaseURL = runtime.databaseURL {
            configRepository = (try? SQLiteConfigRepository(databaseURL: databaseURL, keychainStore: keychainStore)) ?? InMemoryConfigRepository()
        } else {
            configRepository = (try? SQLiteConfigRepository.makeDefault()) ?? InMemoryConfigRepository()
        }

        let authSettingsStore = FileAuthSettingsStore(
            baseDirectoryOverride: runtime.authSettingsDirectory,
            keychainStore: keychainStore
        )
        let authRepository: any AuthRepository
        let repositoryCatalog: any RepositoryCatalog
        let syncExecutor: any SyncExecutor

        if runtime.useMockServices {
            authRepository = MockGitHubAuthRepository()
            repositoryCatalog = MockRepositoryCatalog()
            syncExecutor = MockSyncExecutor()
        } else {
            let configurationLoader = GitHubAuthConfigurationLoader(
                baseDirectoryOverride: runtime.authSettingsDirectory,
                keychainStore: keychainStore
            )
            let authService = GitHubAuthRepository(
                configurationLoader: configurationLoader,
                keychainStore: keychainStore
            )
            authRepository = ConfigAwareAuthRepository(
                configurationLoader: configurationLoader,
                keychainStore: keychainStore
            )
            repositoryCatalog = ConfigAwareRepositoryCatalog(
                client: GitHubAPIClient(authRepository: authService),
                configurationLoader: configurationLoader
            )
            syncExecutor = ConfigAwareSyncExecutor(
                realExecutor: GitHubSyncExecutor(
                    client: GitHubActionsAPIClient(authRepository: authService),
                    encryptionService: GitHubSecretEncryptionService()
                ),
                configurationLoader: configurationLoader
            )
        }

        return AppContainer(
            signInUseCase: SignInUseCase(authRepository: authRepository),
            fetchRepositoriesUseCase: FetchRepositoriesUseCase(repositoryCatalog: repositoryCatalog),
            loadConfigItemsUseCase: LoadConfigItemsUseCase(configRepository: configRepository),
            saveConfigItemUseCase: SaveConfigItemUseCase(configRepository: configRepository),
            deleteConfigItemUseCase: DeleteConfigItemUseCase(configRepository: configRepository),
            syncConfigItemsUseCase: SyncConfigItemsUseCase(syncExecutor: syncExecutor),
            authSettingsStore: authSettingsStore,
            shouldRestoreSessionOnLaunch: !runtime.skipSessionRestore,
            shouldOpenAuthorizationURL: !runtime.useMockServices,
            shouldUsePlaintextSecretEditorForAutomation: runtime.isEnabled
        )
    }
}

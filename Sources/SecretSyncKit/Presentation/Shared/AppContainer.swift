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

    public init(
        signInUseCase: SignInUseCase,
        fetchRepositoriesUseCase: FetchRepositoriesUseCase,
        loadConfigItemsUseCase: LoadConfigItemsUseCase,
        saveConfigItemUseCase: SaveConfigItemUseCase,
        deleteConfigItemUseCase: DeleteConfigItemUseCase,
        syncConfigItemsUseCase: SyncConfigItemsUseCase,
        authSettingsStore: any AuthSettingsStore,
        shouldRestoreSessionOnLaunch: Bool
    ) {
        self.signInUseCase = signInUseCase
        self.fetchRepositoriesUseCase = fetchRepositoriesUseCase
        self.loadConfigItemsUseCase = loadConfigItemsUseCase
        self.saveConfigItemUseCase = saveConfigItemUseCase
        self.deleteConfigItemUseCase = deleteConfigItemUseCase
        self.syncConfigItemsUseCase = syncConfigItemsUseCase
        self.authSettingsStore = authSettingsStore
        self.shouldRestoreSessionOnLaunch = shouldRestoreSessionOnLaunch
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

        let authSettingsStore = FileAuthSettingsStore(baseDirectoryOverride: runtime.authSettingsDirectory)
        let authRepository: any AuthRepository
        let repositoryCatalog: any RepositoryCatalog
        let syncExecutor: any SyncExecutor

        if runtime.useMockServices {
            authRepository = MockGitHubAuthRepository()
            repositoryCatalog = MockRepositoryCatalog()
            syncExecutor = MockSyncExecutor()
        } else {
            let authService = GitHubAuthRepository(keychainStore: keychainStore)
            authRepository = ConfigAwareAuthRepository(keychainStore: keychainStore)
            repositoryCatalog = ConfigAwareRepositoryCatalog(
                client: GitHubAPIClient(authRepository: authService)
            )
            syncExecutor = ConfigAwareSyncExecutor(
                realExecutor: GitHubSyncExecutor(
                    client: GitHubActionsAPIClient(authRepository: authService),
                    encryptionService: PlaceholderSecretEncryptionService()
                )
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
            shouldRestoreSessionOnLaunch: !runtime.skipSessionRestore
        )
    }
}

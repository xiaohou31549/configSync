import Foundation

public struct AppContainer: Sendable {
    public let signInUseCase: SignInUseCase
    public let fetchRepositoriesUseCase: FetchRepositoriesUseCase
    public let loadConfigItemsUseCase: LoadConfigItemsUseCase
    public let saveConfigItemUseCase: SaveConfigItemUseCase
    public let deleteConfigItemUseCase: DeleteConfigItemUseCase
    public let syncConfigItemsUseCase: SyncConfigItemsUseCase
    public let authSettingsStore: any AuthSettingsStore

    public init(
        signInUseCase: SignInUseCase,
        fetchRepositoriesUseCase: FetchRepositoriesUseCase,
        loadConfigItemsUseCase: LoadConfigItemsUseCase,
        saveConfigItemUseCase: SaveConfigItemUseCase,
        deleteConfigItemUseCase: DeleteConfigItemUseCase,
        syncConfigItemsUseCase: SyncConfigItemsUseCase,
        authSettingsStore: any AuthSettingsStore
    ) {
        self.signInUseCase = signInUseCase
        self.fetchRepositoriesUseCase = fetchRepositoriesUseCase
        self.loadConfigItemsUseCase = loadConfigItemsUseCase
        self.saveConfigItemUseCase = saveConfigItemUseCase
        self.deleteConfigItemUseCase = deleteConfigItemUseCase
        self.syncConfigItemsUseCase = syncConfigItemsUseCase
        self.authSettingsStore = authSettingsStore
    }

    public static func bootstrap() -> AppContainer {
        let configRepository: any ConfigRepository = (try? SQLiteConfigRepository.makeDefault()) ?? InMemoryConfigRepository()
        let authSettingsStore = FileAuthSettingsStore()
        let authRepository = ConfigAwareAuthRepository()
        let githubAuthRepository = GitHubAuthRepository()
        let repositoryCatalog = ConfigAwareRepositoryCatalog(
            client: GitHubAPIClient(authRepository: githubAuthRepository)
        )
        let syncExecutor = ConfigAwareSyncExecutor(
            realExecutor: GitHubSyncExecutor(
                client: GitHubActionsAPIClient(authRepository: githubAuthRepository),
                encryptionService: PlaceholderSecretEncryptionService()
            )
        )

        return AppContainer(
            signInUseCase: SignInUseCase(authRepository: authRepository),
            fetchRepositoriesUseCase: FetchRepositoriesUseCase(repositoryCatalog: repositoryCatalog),
            loadConfigItemsUseCase: LoadConfigItemsUseCase(configRepository: configRepository),
            saveConfigItemUseCase: SaveConfigItemUseCase(configRepository: configRepository),
            deleteConfigItemUseCase: DeleteConfigItemUseCase(configRepository: configRepository),
            syncConfigItemsUseCase: SyncConfigItemsUseCase(syncExecutor: syncExecutor),
            authSettingsStore: authSettingsStore
        )
    }
}

import Foundation

public struct AppContainer: Sendable {
    public let signInUseCase: SignInUseCase
    public let fetchRepositoriesUseCase: FetchRepositoriesUseCase
    public let loadConfigItemsUseCase: LoadConfigItemsUseCase
    public let saveConfigItemUseCase: SaveConfigItemUseCase
    public let deleteConfigItemUseCase: DeleteConfigItemUseCase
    public let syncConfigItemsUseCase: SyncConfigItemsUseCase

    public init(
        signInUseCase: SignInUseCase,
        fetchRepositoriesUseCase: FetchRepositoriesUseCase,
        loadConfigItemsUseCase: LoadConfigItemsUseCase,
        saveConfigItemUseCase: SaveConfigItemUseCase,
        deleteConfigItemUseCase: DeleteConfigItemUseCase,
        syncConfigItemsUseCase: SyncConfigItemsUseCase
    ) {
        self.signInUseCase = signInUseCase
        self.fetchRepositoriesUseCase = fetchRepositoriesUseCase
        self.loadConfigItemsUseCase = loadConfigItemsUseCase
        self.saveConfigItemUseCase = saveConfigItemUseCase
        self.deleteConfigItemUseCase = deleteConfigItemUseCase
        self.syncConfigItemsUseCase = syncConfigItemsUseCase
    }

    public static func bootstrap() -> AppContainer {
        let configRepository: any ConfigRepository = (try? SQLiteConfigRepository.makeDefault()) ?? InMemoryConfigRepository()
        let configurationLoader = GitHubAuthConfigurationLoader()

        let authRepository: any AuthRepository
        let repositoryCatalog: any RepositoryCatalog
        let syncExecutor: any SyncExecutor

        if (try? configurationLoader.loadIfAvailable()) != nil {
            let githubAuthRepository = GitHubAuthRepository(configurationLoader: configurationLoader)
            authRepository = githubAuthRepository
            repositoryCatalog = GitHubRepositoryCatalog(client: GitHubAPIClient(authRepository: githubAuthRepository))
            syncExecutor = GitHubSyncExecutor(
                client: GitHubActionsAPIClient(authRepository: githubAuthRepository),
                encryptionService: PlaceholderSecretEncryptionService()
            )
        } else {
            authRepository = MockGitHubAuthRepository()
            repositoryCatalog = MockRepositoryCatalog()
            syncExecutor = MockSyncExecutor()
        }

        return AppContainer(
            signInUseCase: SignInUseCase(authRepository: authRepository),
            fetchRepositoriesUseCase: FetchRepositoriesUseCase(repositoryCatalog: repositoryCatalog),
            loadConfigItemsUseCase: LoadConfigItemsUseCase(configRepository: configRepository),
            saveConfigItemUseCase: SaveConfigItemUseCase(configRepository: configRepository),
            deleteConfigItemUseCase: DeleteConfigItemUseCase(configRepository: configRepository),
            syncConfigItemsUseCase: SyncConfigItemsUseCase(syncExecutor: syncExecutor)
        )
    }
}

import Foundation

public actor ConfigAwareAuthRepository: AuthRepository {
    private let configurationLoader: GitHubAuthConfigurationLoader
    private let keychainStore: KeychainStore
    private let session: URLSession
    private let mockRepository: MockGitHubAuthRepository

    public init(
        configurationLoader: GitHubAuthConfigurationLoader = GitHubAuthConfigurationLoader(),
        keychainStore: KeychainStore = KeychainStore(),
        session: URLSession = .shared,
        mockRepository: MockGitHubAuthRepository = MockGitHubAuthRepository()
    ) {
        self.configurationLoader = configurationLoader
        self.keychainStore = keychainStore
        self.session = session
        self.mockRepository = mockRepository
    }

    public func currentSession() async throws -> UserSession? {
        if try configurationLoader.loadIfAvailable() != nil {
            return try await makeGitHubAuthRepository().currentSession()
        }
        return try await mockRepository.currentSession()
    }

    public func signIn(progress: AuthProgressHandler?) async throws -> UserSession {
        if try configurationLoader.loadIfAvailable() != nil {
            return try await makeGitHubAuthRepository().signIn(progress: progress)
        }
        return try await mockRepository.signIn(progress: progress)
    }

    public func signOut() async throws {
        if try configurationLoader.loadIfAvailable() != nil {
            try await makeGitHubAuthRepository().signOut()
        }
        try await mockRepository.signOut()
    }

    private func makeGitHubAuthRepository() -> GitHubAuthRepository {
        GitHubAuthRepository(
            configurationLoader: configurationLoader,
            oauthService: GitHubOAuthService(session: session),
            keychainStore: keychainStore,
            session: session
        )
    }
}

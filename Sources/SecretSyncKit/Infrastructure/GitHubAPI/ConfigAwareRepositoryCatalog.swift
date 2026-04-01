import Foundation

public struct ConfigAwareRepositoryCatalog: RepositoryCatalog {
    private let mockCatalog: MockRepositoryCatalog
    private let client: GitHubAPIClient
    private let configurationLoader: GitHubAuthConfigurationLoader

    public init(
        client: GitHubAPIClient,
        configurationLoader: GitHubAuthConfigurationLoader = GitHubAuthConfigurationLoader(),
        mockCatalog: MockRepositoryCatalog = MockRepositoryCatalog()
    ) {
        self.client = client
        self.configurationLoader = configurationLoader
        self.mockCatalog = mockCatalog
    }

    public func fetchRepositories() async throws -> [Repo] {
        if try configurationLoader.loadIfAvailable() != nil {
            return try await client.fetchRepositories()
        }
        return try await mockCatalog.fetchRepositories()
    }
}

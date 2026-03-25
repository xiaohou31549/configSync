import Foundation

public struct ConfigAwareRepositoryCatalog: RepositoryCatalog {
    private let mockCatalog: MockRepositoryCatalog
    private let client: GitHubAPIClient

    public init(
        client: GitHubAPIClient,
        mockCatalog: MockRepositoryCatalog = MockRepositoryCatalog()
    ) {
        self.client = client
        self.mockCatalog = mockCatalog
    }

    public func fetchRepositories() async throws -> [Repo] {
        if try GitHubAuthConfigurationLoader().loadIfAvailable() != nil {
            return try await client.fetchRepositories()
        }
        return try await mockCatalog.fetchRepositories()
    }
}

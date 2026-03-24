import Foundation

public struct GitHubRepositoryCatalog: RepositoryCatalog {
    private let client: GitHubAPIClient

    public init(client: GitHubAPIClient) {
        self.client = client
    }

    public func fetchRepositories() async throws -> [Repo] {
        try await client.fetchRepositories()
    }
}

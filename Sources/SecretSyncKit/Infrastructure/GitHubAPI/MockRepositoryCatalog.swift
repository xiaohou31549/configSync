import Foundation

public struct MockRepositoryCatalog: RepositoryCatalog {
    public init() {}

    public func fetchRepositories() async throws -> [Repo] {
        try await Task.sleep(for: .milliseconds(300))
        return SampleData.repos
    }
}

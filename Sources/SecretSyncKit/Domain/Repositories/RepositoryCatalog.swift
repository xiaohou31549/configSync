import Foundation

public protocol RepositoryCatalog: Sendable {
    func fetchRepositories() async throws -> [Repo]
}

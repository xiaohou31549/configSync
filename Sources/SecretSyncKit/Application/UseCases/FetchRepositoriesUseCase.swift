import Foundation

public struct FetchRepositoriesUseCase: Sendable {
    private let repositoryCatalog: RepositoryCatalog

    public init(repositoryCatalog: RepositoryCatalog) {
        self.repositoryCatalog = repositoryCatalog
    }

    public func execute() async throws -> [Repo] {
        try await repositoryCatalog.fetchRepositories()
            .sorted { $0.fullName.lowercased() < $1.fullName.lowercased() }
    }
}

import Foundation

public struct ConfigAwareSyncExecutor: SyncExecutor {
    private let realExecutor: GitHubSyncExecutor
    private let mockExecutor: MockSyncExecutor
    private let configurationLoader: GitHubAuthConfigurationLoader

    public init(
        realExecutor: GitHubSyncExecutor,
        configurationLoader: GitHubAuthConfigurationLoader = GitHubAuthConfigurationLoader(),
        mockExecutor: MockSyncExecutor = MockSyncExecutor()
    ) {
        self.realExecutor = realExecutor
        self.configurationLoader = configurationLoader
        self.mockExecutor = mockExecutor
    }

    public func sync(_ request: SyncRequest) async throws -> SyncSummary {
        if try configurationLoader.loadIfAvailable() != nil {
            return try await realExecutor.sync(request)
        }
        return try await mockExecutor.sync(request)
    }
}

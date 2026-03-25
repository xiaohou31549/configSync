import Foundation

public struct ConfigAwareSyncExecutor: SyncExecutor {
    private let realExecutor: GitHubSyncExecutor
    private let mockExecutor: MockSyncExecutor

    public init(
        realExecutor: GitHubSyncExecutor,
        mockExecutor: MockSyncExecutor = MockSyncExecutor()
    ) {
        self.realExecutor = realExecutor
        self.mockExecutor = mockExecutor
    }

    public func sync(_ request: SyncRequest) async throws -> SyncSummary {
        if try GitHubAuthConfigurationLoader().loadIfAvailable() != nil {
            return try await realExecutor.sync(request)
        }
        return try await mockExecutor.sync(request)
    }
}

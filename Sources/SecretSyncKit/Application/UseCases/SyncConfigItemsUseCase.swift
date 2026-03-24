import Foundation

public struct SyncConfigItemsUseCase: Sendable {
    private let syncExecutor: SyncExecutor

    public init(syncExecutor: SyncExecutor) {
        self.syncExecutor = syncExecutor
    }

    public func execute(repos: [Repo], items: [ConfigItem], overwriteExisting: Bool) async throws -> SyncSummary {
        guard !repos.isEmpty else {
            throw AppError.validation("至少选择一个仓库")
        }

        guard !items.isEmpty else {
            throw AppError.validation("至少选择一个配置项")
        }

        return try await syncExecutor.sync(
            SyncRequest(repos: repos, items: items, overwriteExisting: overwriteExisting)
        )
    }
}

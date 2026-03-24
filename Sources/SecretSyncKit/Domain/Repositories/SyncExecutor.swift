import Foundation

public protocol SyncExecutor: Sendable {
    func sync(_ request: SyncRequest) async throws -> SyncSummary
}

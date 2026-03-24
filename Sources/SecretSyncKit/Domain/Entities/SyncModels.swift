import Foundation

public struct SyncRequest: Sendable {
    public let repos: [Repo]
    public let items: [ConfigItem]
    public let overwriteExisting: Bool

    public init(repos: [Repo], items: [ConfigItem], overwriteExisting: Bool) {
        self.repos = repos
        self.items = items
        self.overwriteExisting = overwriteExisting
    }
}

public enum SyncStatus: Equatable, Sendable {
    case success
    case failed(String)
}

public struct SyncResult: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let repoFullName: String
    public let itemName: String
    public let itemType: ConfigItemType
    public let status: SyncStatus

    public init(
        repoFullName: String,
        itemName: String,
        itemType: ConfigItemType,
        status: SyncStatus
    ) {
        self.repoFullName = repoFullName
        self.itemName = itemName
        self.itemType = itemType
        self.status = status
    }
}

public struct SyncSummary: Equatable, Sendable {
    public let startedAt: Date
    public let endedAt: Date
    public let results: [SyncResult]

    public init(startedAt: Date, endedAt: Date, results: [SyncResult]) {
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.results = results
    }

    public var successCount: Int {
        results.filter {
            if case .success = $0.status { return true }
            return false
        }.count
    }

    public var failureCount: Int {
        results.count - successCount
    }
}

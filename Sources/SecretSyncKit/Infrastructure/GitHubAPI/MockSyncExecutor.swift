import Foundation

public struct MockSyncExecutor: SyncExecutor {
    public init() {}

    public func sync(_ request: SyncRequest) async throws -> SyncSummary {
        let startedAt = Date()
        var results: [SyncResult] = []

        for repo in request.repos {
            for item in request.items {
                try await Task.sleep(for: .milliseconds(120))

                if repo.archived {
                    results.append(
                        SyncResult(
                            repoFullName: repo.fullName,
                            itemName: item.name,
                            itemType: item.type,
                            status: .failed("仓库已归档，禁止写入")
                        )
                    )
                    continue
                }

                if item.name.contains("FAIL") {
                    results.append(
                        SyncResult(
                            repoFullName: repo.fullName,
                            itemName: item.name,
                            itemType: item.type,
                            status: .failed("模拟 GitHub API 返回 403")
                        )
                    )
                    continue
                }

                results.append(
                    SyncResult(
                        repoFullName: repo.fullName,
                        itemName: item.name,
                        itemType: item.type,
                        status: .success
                    )
                )
            }
        }

        return SyncSummary(startedAt: startedAt, endedAt: Date(), results: results)
    }
}

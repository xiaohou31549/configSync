import Foundation

public struct GitHubSyncExecutor: SyncExecutor {
    private let client: GitHubActionsAPIClient
    private let encryptionService: SecretEncryptionService
    private let maxConcurrentRepositories: Int

    public init(
        client: GitHubActionsAPIClient,
        encryptionService: SecretEncryptionService,
        maxConcurrentRepositories: Int = 3
    ) {
        self.client = client
        self.encryptionService = encryptionService
        self.maxConcurrentRepositories = max(1, maxConcurrentRepositories)
    }

    public func sync(_ request: SyncRequest) async throws -> SyncSummary {
        let startedAt = Date()
        var results: [SyncResult] = []

        for batch in request.repos.chunked(into: maxConcurrentRepositories) {
            let batchResults = await withTaskGroup(of: [SyncResult].self) { group in
                for repo in batch {
                    group.addTask {
                        await syncRepository(repo, items: request.items)
                    }
                }

                var merged: [SyncResult] = []
                for await repoResults in group {
                    merged.append(contentsOf: repoResults)
                }
                return merged
            }
            results.append(contentsOf: batchResults)
        }

        return SyncSummary(startedAt: startedAt, endedAt: Date(), results: results)
    }

    private func syncRepository(_ repo: Repo, items: [ConfigItem]) async -> [SyncResult] {
        let target: RepositoryTarget
        do {
            target = try RepositoryTarget(fullName: repo.fullName)
        } catch {
            return items.map {
                SyncResult(
                    repoFullName: repo.fullName,
                    itemName: $0.name,
                    itemType: $0.type,
                    status: .failed(error.localizedDescription)
                )
            }
        }

        var publicKey: RepositoryPublicKey?
        var results: [SyncResult] = []

        for item in items {
            do {
                switch item.type {
                case .secret:
                    if publicKey == nil {
                        publicKey = try await client.fetchRepositoryPublicKey(
                            owner: target.owner,
                            repo: target.repo,
                            installationID: repo.installationID
                        )
                    }
                    guard let publicKey else {
                        throw AppError.infrastructure("缺少仓库公钥")
                    }
                    let encryptedValue = try encryptionService.encrypt(item.value, publicKey: publicKey.key)
                    try await client.upsertRepositorySecret(
                        owner: target.owner,
                        repo: target.repo,
                        installationID: repo.installationID,
                        name: item.name,
                        encryptedValue: encryptedValue,
                        keyID: publicKey.keyID
                    )
                case .variable:
                    try await client.upsertRepositoryVariable(
                        owner: target.owner,
                        repo: target.repo,
                        installationID: repo.installationID,
                        name: item.name,
                        value: item.value
                    )
                }

                results.append(
                    SyncResult(
                        repoFullName: repo.fullName,
                        itemName: item.name,
                        itemType: item.type,
                        status: .success
                    )
                )
            } catch {
                results.append(
                    SyncResult(
                        repoFullName: repo.fullName,
                        itemName: item.name,
                        itemType: item.type,
                        status: .failed(mapError(error))
                    )
                )
            }
        }

        return results
    }

    private func mapError(_ error: Error) -> String {
        if let appError = error as? AppError {
            return appError.errorDescription ?? "未知错误"
        }

        if let apiError = error as? GitHubAPIError {
            switch apiError.statusCode {
            case 401:
                return "未授权，请重新登录 GitHub"
            case 403:
                return "权限不足，或 GitHub App 未获得所需仓库权限"
            case 404:
                return "目标仓库或接口不存在"
            case 409:
                return "资源冲突：\(apiError.message)"
            case 422:
                return "请求校验失败：\(apiError.message)"
            case 429:
                return "GitHub API 限流，请稍后重试"
            case 500 ... 599:
                return "GitHub 服务暂时不可用：HTTP \(apiError.statusCode)"
            default:
                return "GitHub API 错误：HTTP \(apiError.statusCode) \(apiError.message)"
            }
        }

        return error.localizedDescription
    }
}

private struct RepositoryTarget: Sendable {
    let owner: String
    let repo: String

    init(fullName: String) throws {
        let components = fullName.split(separator: "/", omittingEmptySubsequences: true)
        guard components.count == 2 else {
            throw AppError.validation("仓库名称格式无效：\(fullName)")
        }
        self.owner = String(components[0])
        self.repo = String(components[1])
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

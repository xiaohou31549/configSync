import Testing
@testable import SecretSyncKit
import Foundation

@Test("保存配置项时会规范化名称")
func saveConfigNormalizesName() async throws {
    let repository = InMemoryConfigRepository(seedItems: [])
    let useCase = SaveConfigItemUseCase(configRepository: repository)

    let item = try await useCase.execute(
        ConfigItemDraft(name: "  vps_host ", type: .secret, value: "1.1.1.1", description: "host")
    )

    #expect(item.name == "VPS_HOST")
}

@Test("同步时要求至少一个仓库和配置项")
func syncValidatesSelections() async throws {
    let useCase = SyncConfigItemsUseCase(syncExecutor: MockSyncExecutor())

    await #expect(throws: AppError.self) {
        _ = try await useCase.execute(repos: [], items: SampleData.configItems, overwriteExisting: true)
    }

    await #expect(throws: AppError.self) {
        _ = try await useCase.execute(repos: SampleData.repos, items: [], overwriteExisting: true)
    }
}

@Test("优先从环境变量读取 GitHub App client_id")
func authConfigurationLoadsFromEnvironment() throws {
    let loader = GitHubAuthConfigurationLoader(
        environment: [
            "GITHUB_CLIENT_ID": "Iv1.testclient",
            "GITHUB_CLIENT_SECRET": "secret-123"
        ]
    )

    let configuration = try loader.loadIfAvailable()

    #expect(configuration?.clientID == "Iv1.testclient")
    #expect(configuration?.clientSecret == "secret-123")
}

@Test("TokenBundle 会在临近过期时判定为失效")
func tokenBundleExpiryCheck() {
    let expired = TokenBundle(
        accessToken: "ghu_test",
        refreshToken: "ghr_test",
        expiresAt: Date().addingTimeInterval(20),
        refreshTokenExpiresAt: Date().addingTimeInterval(1000),
        tokenType: "bearer"
    )

    #expect(expired.isExpired)
    #expect(expired.refreshTokenUsable)
}

@Test("仓库全名会被拆分为 owner 和 repo")
func repositoryTargetParsing() async throws {
    let syncExecutor = GitHubSyncExecutor(
        client: GitHubActionsAPIClient(
            authRepository: GitHubAuthRepository(
                configurationLoader: GitHubAuthConfigurationLoader(
                    environment: [
                        "GITHUB_CLIENT_ID": "Iv1.test",
                        "GITHUB_CLIENT_SECRET": "secret"
                    ]
                )
            )
        ),
        encryptionService: GitHubSecretEncryptionService()
    )

    let summary = try await syncExecutor.sync(
        SyncRequest(
            repos: [Repo(id: 1, name: "repo", fullName: "invalid-name", owner: "x", visibility: .public, defaultBranch: "main", archived: false)],
            items: [ConfigItem(name: "TEST", type: .variable, value: "1")],
            overwriteExisting: true
        )
    )

    #expect(summary.failureCount == 1)
}

@Test("SQLite 仓库会持久化 Variable 与 Secret")
func sqliteConfigRepositoryPersistsItems() async throws {
    let databaseURL = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString)
        .appending(path: "config.sqlite3")
    let keychainService = "com.tough.SecretSync.tests.\(UUID().uuidString)"
    let repository = try SQLiteConfigRepository(
        databaseURL: databaseURL,
        keychainStore: KeychainStore(service: keychainService)
    )

    let variable = try await repository.save(
        draft: ConfigItemDraft(name: "IMAGE_NAME", type: .variable, value: "ghcr.io/demo/app", description: "")
    )
    let secret = try await repository.save(
        draft: ConfigItemDraft(name: "VPS_KEY", type: .secret, value: "super-secret", description: "")
    )

    let items = try await repository.listItems()

    #expect(items.count == 2)
    #expect(items.contains(where: { $0.id == variable.id && $0.value == "ghcr.io/demo/app" }))
    #expect(items.contains(where: { $0.id == secret.id && $0.value == "super-secret" }))
}

@Test("认证配置会写入并读回本地文件")
func authSettingsStoreRoundTrip() throws {
    let fileManager = FileManager.default
    let root = fileManager.temporaryDirectory.appending(path: UUID().uuidString)
    try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
    let store = FileAuthSettingsStore(baseDirectoryOverride: root)
    let draft = GitHubAuthSettingsDraft(
        clientID: "client-id",
        clientSecret: "client-secret",
        callbackPath: "oauth/callback",
        scopes: "repo read:user"
    )

    try store.saveDraft(draft)
    let loaded = try store.loadDraft()

    #expect(loaded?.clientID == "client-id")
    #expect(loaded?.clientSecret == "client-secret")
    #expect(loaded?.callbackPath == "/oauth/callback")
}

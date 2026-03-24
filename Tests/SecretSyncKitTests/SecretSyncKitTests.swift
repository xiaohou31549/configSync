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
        environment: ["GITHUB_APP_CLIENT_ID": "Iv1.testclient"],
        fileManager: .default
    )

    let configuration = try loader.loadIfAvailable()

    #expect(configuration?.clientID == "Iv1.testclient")
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

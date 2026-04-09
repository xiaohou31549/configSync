import Testing
@testable import SecretSyncKit
import Foundation

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private struct StubRepositoryCatalog: RepositoryCatalog {
    let repositories: [Repo]

    func fetchRepositories() async throws -> [Repo] {
        repositories
    }
}

private actor ProgressRecorder {
    private var events: [GitHubAuthProgress] = []

    func append(_ event: GitHubAuthProgress) {
        events.append(event)
    }

    func snapshot() -> [GitHubAuthProgress] {
        events
    }
}

private struct RecordedRequest: Sendable {
    let url: URL?
    let headers: [String: String]
    let body: String
}

private final class RequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [RecordedRequest] = []

    func append(_ request: RecordedRequest) {
        lock.lock()
        defer { lock.unlock() }
        requests.append(request)
    }

    func snapshot() -> [RecordedRequest] {
        lock.lock()
        defer { lock.unlock() }
        return requests
    }
}

private struct StubEncryptionService: SecretEncryptionService {
    let encryptedValue: String

    func encrypt(_ plaintext: String, publicKey: String) throws -> String {
        guard !plaintext.isEmpty, !publicKey.isEmpty else {
            throw AppError.validation("缺少加密输入")
        }
        return encryptedValue
    }
}

private actor RecordingSyncExecutor: SyncExecutor {
    private(set) var requests: [SyncRequest] = []

    func sync(_ request: SyncRequest) async throws -> SyncSummary {
        requests.append(request)
        return SyncSummary(startedAt: Date(), endedAt: Date(), results: [])
    }

    func snapshot() -> [SyncRequest] {
        requests
    }
}

private actor StubAuthRepository: AuthRepository {
    private let restoredSession: UserSession?

    init(restoredSession: UserSession?) {
        self.restoredSession = restoredSession
    }

    func currentSession() async throws -> UserSession? {
        restoredSession
    }

    func signIn(progress: AuthProgressHandler?) async throws -> UserSession {
        guard let restoredSession else {
            throw AppError.infrastructure("测试未提供可恢复会话")
        }
        return restoredSession
    }

    func signOut() async throws {}
}

private struct ImmediateSuccessSyncExecutor: SyncExecutor {
    func sync(_ request: SyncRequest) async throws -> SyncSummary {
        SyncSummary(startedAt: Date(), endedAt: Date(), results: [])
    }
}

private struct StubSummarySyncExecutor: SyncExecutor {
    let summary: SyncSummary

    func sync(_ request: SyncRequest) async throws -> SyncSummary {
        summary
    }
}

@Test("保存配置项时会规范化名称")
func saveConfigNormalizesName() async throws {
    let repository = InMemoryConfigRepository(seedItems: [])
    let useCase = SaveConfigItemUseCase(configRepository: repository)

    let item = try await useCase.execute(
        ConfigItemDraft(name: "  vps_host ", type: .secret, value: "1.1.1.1", description: "host")
    )

    #expect(item.name == "VPS_HOST")
}

@Test("保存 Secret 时会拒绝重复名称")
func saveSecretRejectsDuplicateName() async throws {
    let existing = ConfigItem(name: "VPS_HOST", type: .secret, value: "old")
    let repository = InMemoryConfigRepository(seedItems: [existing])
    let useCase = SaveConfigItemUseCase(configRepository: repository)

    await #expect(throws: AppError.self) {
        _ = try await useCase.execute(
            ConfigItemDraft(name: "vps_host", type: .secret, value: "new-secret", description: "")
        )
    }
}

@Test("编辑已有 Secret 时会回写新值")
func saveSecretUpdatesExistingItem() async throws {
    let existing = ConfigItem(name: "API_TOKEN", type: .secret, value: "old-token", description: "旧值")
    let repository = InMemoryConfigRepository(seedItems: [existing])
    let useCase = SaveConfigItemUseCase(configRepository: repository)

    let saved = try await useCase.execute(
        ConfigItemDraft(id: existing.id, name: "api_token", type: .secret, value: "new-token", description: "新值")
    )

    let items = try await repository.listItems()
    #expect(saved.id == existing.id)
    #expect(saved.value == "new-token")
    #expect(items.count == 1)
    #expect(items.first?.name == "API_TOKEN")
    #expect(items.first?.value == "new-token")
}

@Test("删除不存在的 Secret 不会报错")
func deleteMissingSecretIsNoop() async throws {
    let repository = InMemoryConfigRepository(seedItems: [])
    let useCase = DeleteConfigItemUseCase(configRepository: repository)

    try await useCase.execute(id: UUID())

    let items = try await repository.listItems()
    #expect(items.isEmpty)
}

@Test("同步时要求至少一个仓库和配置项")
func syncValidatesSelections() async throws {
    let useCase = SyncConfigItemsUseCase(syncExecutor: ImmediateSuccessSyncExecutor())

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
            "GITHUB_APP_ID": "3241508",
            "GITHUB_APP_CLIENT_ID": "Iv1.testclient",
            "GITHUB_APP_CLIENT_SECRET": "secret-123",
            "GITHUB_APP_SLUG": "secretvarsync",
            "GITHUB_APP_PRIVATE_KEY_PATH": "/tmp/secretvarsync.pem"
        ]
    )

    let configuration = try loader.loadIfAvailable()

    #expect(configuration?.appID == "3241508")
    #expect(configuration?.clientID == "Iv1.testclient")
    #expect(configuration?.clientSecret == "secret-123")
    #expect(configuration?.slug == "secretvarsync")
    #expect(configuration?.privateKeyPath == "/tmp/secretvarsync.pem")
}

@Test("认证配置可从本地 auth.json 加载")
func authConfigurationLoadsFromLocalFile() throws {
    let fileManager = FileManager.default
    let root = fileManager.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try fileManager.createDirectory(at: root, withIntermediateDirectories: true)

    let configuration = StoredGitHubAuthConfiguration(
        appID: "3241508",
        clientID: "Iv1.fileclient",
        slug: "secretvarsync",
        privateKeyPath: "/tmp/secretvarsync.pem",
        callbackPath: "/oauth/callback",
        clientSecret: "file-secret"
    )
    let data = try JSONEncoder().encode(configuration)
    try data.write(to: root.appending(path: "auth.json"))

    let loader = GitHubAuthConfigurationLoader(
        environment: [:],
        baseDirectoryOverride: root
    )

    let loaded = try loader.loadIfAvailable()

    #expect(loaded?.appID == "3241508")
    #expect(loaded?.clientID == "Iv1.fileclient")
    #expect(loaded?.clientSecret == "file-secret")
    #expect(loaded?.slug == "secretvarsync")
    #expect(loaded?.privateKeyPath == "/tmp/secretvarsync.pem")
}

@Test("认证配置可兼容读取旧版包含 Client Secret 的 auth.json")
func authConfigurationLoadsLegacyFile() throws {
    let fileManager = FileManager.default
    let root = fileManager.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try fileManager.createDirectory(at: root, withIntermediateDirectories: true)

    let configuration = GitHubAuthConfiguration(
        appID: "3241508",
        clientID: "Iv1.legacyclient",
        clientSecret: "legacy-secret",
        slug: "secretvarsync",
        privateKeyPath: "/tmp/secretvarsync.pem",
        callbackPath: "/oauth/callback"
    )
    let data = try JSONEncoder().encode(configuration)
    try data.write(to: root.appending(path: "auth.json"))

    let loader = GitHubAuthConfigurationLoader(
        environment: [:],
        baseDirectoryOverride: root
    )

    let loaded = try loader.loadIfAvailable()

    #expect(loaded == configuration)
}

@Test("认证配置可从应用内置 GitHub App 配置加载")
func authConfigurationLoadsFromBundledConfiguration() throws {
    let bundled = """
    {
      "appID": "3241508",
      "clientID": "Iv1.bundledclient",
      "clientSecret": "bundled-secret",
      "slug": "secretvarsync",
      "privateKeyResource": "BundledGitHubAppPrivateKey.pem",
      "callbackPath": "/oauth/callback"
    }
    """.data(using: .utf8)!
    let expectedPrivateKeyURL = URL(filePath: "/Applications/SecretSync.app/Contents/Resources/BundledGitHubAppPrivateKey.pem")
    let loader = GitHubAuthConfigurationLoader(
        environment: [:],
        bundledConfigurationData: bundled,
        bundledResourceResolver: { resourceName in
            if resourceName == "BundledGitHubAppPrivateKey.pem" {
                return expectedPrivateKeyURL
            }
            return nil
        }
    )

    let loaded = try loader.loadResolvedConfiguration()

    #expect(loaded?.source == .bundledApp)
    #expect(loaded?.configuration.appID == "3241508")
    #expect(loaded?.configuration.clientID == "Iv1.bundledclient")
    #expect(loaded?.configuration.clientSecret == "bundled-secret")
    #expect(loaded?.configuration.privateKeyPath == expectedPrivateKeyURL.path())
}

@Test("本地 auth.json 会优先覆盖应用内置 GitHub App 配置")
func localAuthConfigurationOverridesBundledConfiguration() throws {
    let fileManager = FileManager.default
    let root = fileManager.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try fileManager.createDirectory(at: root, withIntermediateDirectories: true)

    let localConfiguration = StoredGitHubAuthConfiguration(
        appID: "3241508",
        clientID: "Iv1.localclient",
        slug: "secretvarsync",
        privateKeyPath: "/tmp/local.pem",
        callbackPath: "/oauth/callback",
        clientSecret: "local-secret"
    )
    let localData = try JSONEncoder().encode(localConfiguration)
    try localData.write(to: root.appending(path: "auth.json"))

    let bundled = """
    {
      "appID": "3241508",
      "clientID": "Iv1.bundledclient",
      "clientSecret": "bundled-secret",
      "slug": "secretvarsync",
      "privateKeyPath": "/tmp/bundled.pem",
      "callbackPath": "/oauth/callback"
    }
    """.data(using: .utf8)!

    let loader = GitHubAuthConfigurationLoader(
        environment: [:],
        baseDirectoryOverride: root,
        bundledConfigurationData: bundled
    )

    let loaded = try loader.loadResolvedConfiguration()

    #expect(loaded?.source == .localFile)
    #expect(loaded?.configuration.clientID == "Iv1.localclient")
    #expect(loaded?.configuration.clientSecret == "local-secret")
    #expect(loaded?.configuration.privateKeyPath == "/tmp/local.pem")
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
                        "GITHUB_APP_ID": "3241508",
                        "GITHUB_APP_CLIENT_ID": "Iv1.test",
                        "GITHUB_APP_CLIENT_SECRET": "secret",
                        "GITHUB_APP_SLUG": "secretvarsync",
                        "GITHUB_APP_PRIVATE_KEY_PATH": "/tmp/secretvarsync.pem"
                    ]
                )
            )
        ),
        encryptionService: GitHubSecretEncryptionService()
    )

    let summary = try await syncExecutor.sync(
        SyncRequest(
            repos: [Repo(id: 1, installationID: 101, name: "repo", fullName: "invalid-name", owner: "x", visibility: .public, defaultBranch: "main", archived: false)],
            items: [ConfigItem(name: "TEST", type: .variable, value: "1")],
            overwriteExisting: true
        )
    )

    #expect(summary.failureCount == 1)
}

@Test("GitHub App 授权地址会使用本机 loopback 回调")
func githubAppAuthorizationUsesLoopbackCallback() throws {
    let service = GitHubOAuthService()
    let configuration = GitHubAuthConfiguration(
        appID: "3241508",
        clientID: "Iv1.testclient",
        clientSecret: "secret-123",
        slug: "secretvarsync",
        privateKeyPath: "/tmp/secretvarsync.pem",
        callbackPath: "/oauth/callback"
    )

    let context = try service.prepareAuthorization(configuration: configuration)
    let components = URLComponents(url: context.authorizationURL, resolvingAgainstBaseURL: false)
    let queryMap = Dictionary(uniqueKeysWithValues: (components?.queryItems ?? []).map { ($0.name, $0.value ?? "") })

    #expect(context.redirectURI.hasPrefix("http://127.0.0.1:"))
    #expect(context.redirectURI.hasSuffix("/oauth/callback"))
    #expect(context.port > 0)
    #expect(queryMap["client_id"] == "Iv1.testclient")
    #expect(queryMap["redirect_uri"] == context.redirectURI)
    #expect(queryMap["code_challenge_method"] == "S256")
    #expect((queryMap["state"] ?? "").isEmpty == false)
    #expect((queryMap["code_challenge"] ?? "").isEmpty == false)
}

@Test("完整 GitHub App 回调地址必须显式包含非特权端口")
func githubAppAuthorizationRejectsCallbackURLWithoutPort() throws {
    let service = GitHubOAuthService()
    let configuration = GitHubAuthConfiguration(
        appID: "3241508",
        clientID: "Iv1.testclient",
        clientSecret: "secret-123",
        slug: "secretvarsync",
        privateKeyPath: "/tmp/secretvarsync.pem",
        callbackPath: "http://127.0.0.1/oauth/callback"
    )

    #expect(throws: AppError.self) {
        _ = try service.prepareAuthorization(configuration: configuration)
    }
}

@Test("完整 GitHub App 回调地址会拒绝特权端口")
func githubAppAuthorizationRejectsPrivilegedCallbackPort() throws {
    let service = GitHubOAuthService()
    let configuration = GitHubAuthConfiguration(
        appID: "3241508",
        clientID: "Iv1.testclient",
        clientSecret: "secret-123",
        slug: "secretvarsync",
        privateKeyPath: "/tmp/secretvarsync.pem",
        callbackPath: "http://127.0.0.1:80/oauth/callback"
    )

    #expect(throws: AppError.self) {
        _ = try service.prepareAuthorization(configuration: configuration)
    }
}

@Test("GitHub App 授权回调可建立并恢复会话")
func githubAppSignInAndRestoreSession() async throws {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockURLProtocol.self]
    let urlSession = URLSession(configuration: configuration)
    let sessionStore = makeSessionStore()
    let authRepository = GitHubAuthRepository(
        configurationLoader: GitHubAuthConfigurationLoader(
            environment: [
                "GITHUB_APP_ID": "3241508",
                "GITHUB_APP_CLIENT_ID": "Iv1.testclient",
                "GITHUB_APP_CLIENT_SECRET": "secret-123",
                "GITHUB_APP_SLUG": "secretvarsync",
                "GITHUB_APP_PRIVATE_KEY_PATH": "/tmp/secretvarsync.pem"
            ]
        ),
        oauthService: GitHubOAuthService(
            session: urlSession,
            authorizationCallbackAwaiter: { context, _ in
                OAuthCallbackPayload(code: "test-code", state: context.state)
            }
        ),
        sessionStore: sessionStore,
        session: urlSession
    )
    let requestRecorder = RequestRecorder()

    MockURLProtocol.requestHandler = { request in
        let url = try #require(request.url)
        requestRecorder.append(
            RecordedRequest(
                url: request.url,
                headers: request.allHTTPHeaderFields ?? [:],
                body: readRequestBody(from: request)
            )
        )
        if url.host == "github.com", url.path == "/login/oauth/access_token" {
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = """
            {
              "access_token": "ghu_test_token",
              "refresh_token": "ghr_test_token",
              "expires_in": 3600,
              "refresh_token_expires_in": 7200,
              "token_type": "bearer"
            }
            """.data(using: .utf8)!
            return (response, data)
        }

        if url.host == "api.github.com", url.path == "/user" {
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer ghu_test_token")
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = #"{"login":"octocat"}"#.data(using: .utf8)!
            return (response, data)
        }

        if url.host == "api.github.com", url.path == "/user/installations" {
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer ghu_test_token")
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = """
            {
              "installations": [
                {
                  "id": 987,
                  "account": {
                    "login": "octo-org",
                    "type": "Organization"
                  }
                }
              ]
            }
            """.data(using: .utf8)!
            return (response, data)
        }

        throw URLError(.unsupportedURL)
    }
    defer { MockURLProtocol.requestHandler = nil }

    let recorder = ProgressRecorder()
    let session = try await authRepository.signIn { progress in
        await recorder.append(progress)
    }
    let restoredSession = try await authRepository.currentSession()
    let progressEvents = await recorder.snapshot()
    let recordedRequests = requestRecorder.snapshot()
    let tokenExchangeRequest = try #require(recordedRequests.first(where: {
        $0.url?.host == "github.com" && $0.url?.path == "/login/oauth/access_token"
    }))
    let userRequest = try #require(recordedRequests.first(where: {
        $0.url?.host == "api.github.com" && $0.url?.path == "/user"
    }))

    #expect(session.username == "octocat")
    #expect(session.accessToken == "ghu_test_token")
    #expect(session.installations == [GitHubInstallation(id: 987, accountLogin: "octo-org", accountType: "Organization")])
    #expect(restoredSession?.username == "octocat")
    #expect(restoredSession?.accessToken == "ghu_test_token")
    #expect(restoredSession?.installations == [GitHubInstallation(id: 987, accountLogin: "octo-org", accountType: "Organization")])
    #expect(tokenExchangeRequest.body.contains("client_id=Iv1.testclient"))
    #expect(tokenExchangeRequest.body.contains("client_secret=secret-123"))
    #expect(tokenExchangeRequest.body.contains("code=test-code"))
    #expect(userRequest.headers["Authorization"] == "Bearer ghu_test_token")
    #expect(progressEvents.contains(where: {
        if case .openingBrowser = $0 { return true }
        return false
    }))
    #expect(progressEvents.contains(.exchangingCode))
    #expect(progressEvents.contains(.loadingProfile))
    #expect(progressEvents.contains(where: {
        if case .completed(username: "octocat") = $0 { return true }
        return false
    }))
}

@Test("GitHub 仓库列表接口会解析 owner、可见性和归档状态")
func githubRepositoryFetchDecodesRepositoryPayload() async throws {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockURLProtocol.self]
    let urlSession = URLSession(configuration: configuration)
    let sessionStore = makeSessionStore(
        accessToken: "ghu_repo_token",
        tokenType: "bearer",
        installations: [GitHubInstallation(id: 987, accountLogin: "octo-org", accountType: "Organization")]
    )
    let authRepository = GitHubAuthRepository(
        configurationLoader: GitHubAuthConfigurationLoader(
            environment: [
                "GITHUB_APP_ID": "3241508",
                "GITHUB_APP_CLIENT_ID": "Iv1.testclient",
                "GITHUB_APP_CLIENT_SECRET": "secret-123",
                "GITHUB_APP_SLUG": "secretvarsync",
                "GITHUB_APP_PRIVATE_KEY_PATH": "/tmp/secretvarsync.pem"
            ]
        ),
        sessionStore: sessionStore,
        session: urlSession
    )
    let client = GitHubAPIClient(authRepository: authRepository, session: urlSession)

    MockURLProtocol.requestHandler = { request in
        let url = try #require(request.url)
        if url.host == "api.github.com", url.path == "/user" {
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, #"{"login":"octocat"}"#.data(using: .utf8)!)
        }

        if url.host == "api.github.com", url.path == "/user/installations" {
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = """
            {
              "installations": [
                {
                  "id": 987,
                  "account": { "login": "octo-org", "type": "Organization" }
                }
              ]
            }
            """.data(using: .utf8)!
            return (response, data)
        }

        if url.host == "api.github.com", url.path == "/user/installations/987/repositories" {
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = """
            {
              "repositories": [
                {
                  "id": 42,
                  "name": "secretsync",
                  "full_name": "octocat/secretsync",
                  "owner": { "login": "octocat" },
                  "private": true,
                  "default_branch": "main",
                  "archived": false
                },
                {
                  "id": 99,
                  "name": "demo",
                  "full_name": "acme/demo",
                  "owner": { "login": "acme" },
                  "private": false,
                  "default_branch": "develop",
                  "archived": true
                }
              ]
            }
            """.data(using: .utf8)!
            return (response, data)
        }

        throw URLError(.unsupportedURL)
    }
    defer { MockURLProtocol.requestHandler = nil }

    let repositories = try await client.fetchRepositories()

    #expect(repositories.count == 2)
    #expect(repositories[0] == Repo(
        id: 99,
        installationID: 987,
        name: "demo",
        fullName: "acme/demo",
        owner: "acme",
        visibility: .public,
        defaultBranch: "develop",
        archived: true
    ))
    #expect(repositories[1] == Repo(
        id: 42,
        installationID: 987,
        name: "secretsync",
        fullName: "octocat/secretsync",
        owner: "octocat",
        visibility: .private,
        defaultBranch: "main",
        archived: false
    ))
}

@Test("登录成功后可立即拉取仓库列表")
func repositoryFetchWorksImmediatelyAfterSignIn() async throws {
    let fileManager = FileManager.default
    let authRoot = fileManager.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try fileManager.createDirectory(at: authRoot, withIntermediateDirectories: true)

    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockURLProtocol.self]
    let urlSession = URLSession(configuration: configuration)
    let authRepository = GitHubAuthRepository(
        configurationLoader: GitHubAuthConfigurationLoader(
            environment: [
                "GITHUB_APP_ID": "3241508",
                "GITHUB_APP_CLIENT_ID": "Iv1.testclient",
                "GITHUB_APP_CLIENT_SECRET": "secret-123",
                "GITHUB_APP_SLUG": "secretvarsync",
                "GITHUB_APP_PRIVATE_KEY_PATH": "/tmp/secretvarsync.pem"
            ]
        ),
        oauthService: GitHubOAuthService(
            session: urlSession,
            authorizationCallbackAwaiter: { context, _ in
                OAuthCallbackPayload(code: "test-code", state: context.state)
            }
        ),
        sessionStore: FileAuthSessionStore(
            stateURL: authRoot.appending(path: "auth-session.json")
        ),
        session: urlSession
    )
    let client = GitHubAPIClient(authRepository: authRepository, session: urlSession)

    MockURLProtocol.requestHandler = { request in
        let url = try #require(request.url)

        switch (url.host, url.path) {
        case ("github.com", "/login/oauth/access_token"):
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = """
            {
              "access_token": "ghu_test_token",
              "refresh_token": "ghr_test_token",
              "expires_in": 28800,
              "refresh_token_expires_in": 15724800,
              "token_type": "bearer"
            }
            """.data(using: .utf8)!
            return (response, data)

        case ("api.github.com", "/user"):
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, #"{"login":"octocat"}"#.data(using: .utf8)!)

        case ("api.github.com", "/user/installations"):
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = """
            {
              "installations": [
                {
                  "id": 987,
                  "account": { "login": "octo-org", "type": "Organization" }
                }
              ]
            }
            """.data(using: .utf8)!
            return (response, data)

        case ("api.github.com", "/user/installations/987/repositories"):
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = """
            {
              "repositories": [
                {
                  "id": 42,
                  "name": "secretsync",
                  "full_name": "octocat/secretsync",
                  "owner": { "login": "octocat" },
                  "private": true,
                  "default_branch": "main",
                  "archived": false
                }
              ]
            }
            """.data(using: .utf8)!
            return (response, data)

        default:
            throw URLError(.unsupportedURL)
        }
    }
    defer { MockURLProtocol.requestHandler = nil }

    let session = try await authRepository.signIn(progress: nil)
    let repositories = try await client.fetchRepositories()

    #expect(session.username == "octocat")
    #expect(repositories.count == 1)
    #expect(repositories.first?.fullName == "octocat/secretsync")
}

@Test("仓库用例会按 fullName 排序")
func fetchRepositoriesUseCaseSortsRepositories() async throws {
    let useCase = FetchRepositoriesUseCase(
        repositoryCatalog: StubRepositoryCatalog(
            repositories: [
                Repo(id: 2, name: "zeta", fullName: "team/zeta", owner: "team", visibility: .private, defaultBranch: "main", archived: false),
                Repo(id: 1, name: "alpha", fullName: "team/alpha", owner: "team", visibility: .public, defaultBranch: "main", archived: false)
            ]
        )
    )

    let repositories = try await useCase.execute()

    #expect(repositories.map(\.fullName) == ["team/alpha", "team/zeta"])
}

@MainActor
@Test("仓库列表支持搜索、筛选与全选可见项")
func repositoryFilteringAndSelectionInViewModel() async throws {
    let repositoryCatalog = StubRepositoryCatalog(
        repositories: [
            Repo(id: 1, name: "alpha", fullName: "acme/alpha", owner: "acme", visibility: .public, defaultBranch: "main", archived: false),
            Repo(id: 2, name: "beta", fullName: "acme/beta", owner: "acme", visibility: .private, defaultBranch: "main", archived: false),
            Repo(id: 3, name: "legacy", fullName: "archive/legacy", owner: "archive", visibility: .public, defaultBranch: "main", archived: true)
        ]
    )
    let configRepository = InMemoryConfigRepository(seedItems: [])
    let authRoot = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: authRoot, withIntermediateDirectories: true)
    let container = AppContainer(
        signInUseCase: SignInUseCase(authRepository: StubAuthRepository(restoredSession: nil)),
        fetchRepositoriesUseCase: FetchRepositoriesUseCase(repositoryCatalog: repositoryCatalog),
        loadConfigItemsUseCase: LoadConfigItemsUseCase(configRepository: configRepository),
        saveConfigItemUseCase: SaveConfigItemUseCase(configRepository: configRepository),
        deleteConfigItemUseCase: DeleteConfigItemUseCase(configRepository: configRepository),
        syncConfigItemsUseCase: SyncConfigItemsUseCase(syncExecutor: ImmediateSuccessSyncExecutor()),
        authSettingsStore: FileAuthSettingsStore(baseDirectoryOverride: authRoot),
        shouldRestoreSessionOnLaunch: false
    )
    let viewModel = AppViewModel(container: container)

    await viewModel.refreshAll()

    let initialRepositories = viewModel.filteredRepositories.map(\.fullName)
    #expect(initialRepositories == ["acme/alpha", "acme/beta"])

    viewModel.repoSearchText = "beta"
    let searchResults = viewModel.filteredRepositories.map(\.fullName)
    #expect(searchResults == ["acme/beta"])

    viewModel.repoSearchText = ""
    viewModel.repoVisibilityFilter = .private
    let privateRepositories = viewModel.filteredRepositories.map(\.fullName)
    #expect(privateRepositories == ["acme/beta"])

    viewModel.repoVisibilityFilter = .all
    viewModel.showArchivedRepositories = true
    viewModel.selectAllVisibleRepositories()
    let allSelected = viewModel.selectedRepoIDs
    #expect(allSelected == [1, 2, 3])

    viewModel.toggleRepositorySelection(2)
    let toggledSelection = viewModel.selectedRepoIDs
    #expect(toggledSelection == [1, 3])
}

@MainActor
@Test("同步前会校验登录、仓库和配置项选择状态")
func syncReadinessBlocksMissingSelections() async throws {
    let configRepository = InMemoryConfigRepository(seedItems: [])
    let authRoot = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: authRoot, withIntermediateDirectories: true)
    let restoredSession = UserSession(
        username: "octocat",
        accessToken: "ghu_token",
        tokenBundle: TokenBundle(accessToken: "ghu_token", refreshToken: nil, expiresAt: nil, refreshTokenExpiresAt: nil, tokenType: "bearer"),
        installations: [GitHubInstallation(id: 987, accountLogin: "octo-org", accountType: "Organization")]
    )
    let container = AppContainer(
        signInUseCase: SignInUseCase(authRepository: StubAuthRepository(restoredSession: restoredSession)),
        fetchRepositoriesUseCase: FetchRepositoriesUseCase(
            repositoryCatalog: StubRepositoryCatalog(
                repositories: [Repo(id: 1, installationID: 987, name: "alpha", fullName: "acme/alpha", owner: "acme", visibility: .public, defaultBranch: "main", archived: false)]
            )
        ),
        loadConfigItemsUseCase: LoadConfigItemsUseCase(configRepository: configRepository),
        saveConfigItemUseCase: SaveConfigItemUseCase(configRepository: configRepository),
        deleteConfigItemUseCase: DeleteConfigItemUseCase(configRepository: configRepository),
        syncConfigItemsUseCase: SyncConfigItemsUseCase(syncExecutor: ImmediateSuccessSyncExecutor()),
        authSettingsStore: FileAuthSettingsStore(baseDirectoryOverride: authRoot),
        shouldRestoreSessionOnLaunch: false
    )
    let viewModel = AppViewModel(container: container)

    await viewModel.refreshAll()
    #expect(viewModel.syncReadiness == .requiresAuthentication)
    #expect(viewModel.canSyncSelection == false)

    viewModel.syncSelected()
    #expect(viewModel.authProgressMessage == "同步前需要先登录 GitHub")

    await viewModel.restoreSession()
    #expect(viewModel.syncReadiness == .requiresRepositorySelection)

    viewModel.selectedRepoIDs = [1]
    #expect(viewModel.syncReadiness == .requiresConfigSelection)
}

@MainActor
@Test("同步前校验通过后才会触发同步执行")
func syncReadinessAllowsReadySelections() async throws {
    let configRepository = InMemoryConfigRepository(
        seedItems: [ConfigItem(name: "API_TOKEN", type: .secret, value: "plain-secret")]
    )
    let authRoot = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: authRoot, withIntermediateDirectories: true)
    let executor = RecordingSyncExecutor()
    let restoredSession = UserSession(
        username: "octocat",
        accessToken: "ghu_token",
        tokenBundle: TokenBundle(accessToken: "ghu_token", refreshToken: nil, expiresAt: nil, refreshTokenExpiresAt: nil, tokenType: "bearer"),
        installations: [GitHubInstallation(id: 987, accountLogin: "octo-org", accountType: "Organization")]
    )
    let container = AppContainer(
        signInUseCase: SignInUseCase(authRepository: StubAuthRepository(restoredSession: restoredSession)),
        fetchRepositoriesUseCase: FetchRepositoriesUseCase(
            repositoryCatalog: StubRepositoryCatalog(
                repositories: [Repo(id: 1, installationID: 987, name: "alpha", fullName: "acme/alpha", owner: "acme", visibility: .public, defaultBranch: "main", archived: false)]
            )
        ),
        loadConfigItemsUseCase: LoadConfigItemsUseCase(configRepository: configRepository),
        saveConfigItemUseCase: SaveConfigItemUseCase(configRepository: configRepository),
        deleteConfigItemUseCase: DeleteConfigItemUseCase(configRepository: configRepository),
        syncConfigItemsUseCase: SyncConfigItemsUseCase(syncExecutor: executor),
        authSettingsStore: FileAuthSettingsStore(baseDirectoryOverride: authRoot),
        shouldRestoreSessionOnLaunch: false
    )
    let viewModel = AppViewModel(container: container)

    await viewModel.refreshAll()
    await viewModel.restoreSession()
    viewModel.selectedRepoIDs = [1]

    #expect(viewModel.syncReadiness == .ready)
    #expect(viewModel.canSyncSelection)

    viewModel.syncSelected()
    try await Task.sleep(for: .milliseconds(50))
    let requests = await executor.snapshot()

    #expect(requests.count == 1)
    #expect(requests[0].repos.map(\.fullName) == ["acme/alpha"])
    #expect(requests[0].items.map(\.name) == ["API_TOKEN"])
}

@MainActor
@Test("同步完成后会在页面状态中保留结果摘要")
func syncSelectedStoresSummaryForFeedback() async throws {
    let configRepository = InMemoryConfigRepository(
        seedItems: [ConfigItem(name: "API_TOKEN", type: .secret, value: "plain-secret")]
    )
    let authRoot = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: authRoot, withIntermediateDirectories: true)
    let restoredSession = UserSession(
        username: "octocat",
        accessToken: "ghu_token",
        tokenBundle: TokenBundle(accessToken: "ghu_token", refreshToken: nil, expiresAt: nil, refreshTokenExpiresAt: nil, tokenType: "bearer"),
        installations: [GitHubInstallation(id: 987, accountLogin: "octo-org", accountType: "Organization")]
    )
    let summary = SyncSummary(
        startedAt: Date(),
        endedAt: Date(),
        results: [
            SyncResult(repoFullName: "acme/alpha", itemName: "API_TOKEN", itemType: .secret, status: .success),
            SyncResult(repoFullName: "acme/beta", itemName: "API_TOKEN", itemType: .secret, status: .failed("权限不足"))
        ]
    )
    let container = AppContainer(
        signInUseCase: SignInUseCase(authRepository: StubAuthRepository(restoredSession: restoredSession)),
        fetchRepositoriesUseCase: FetchRepositoriesUseCase(
            repositoryCatalog: StubRepositoryCatalog(
                repositories: [
                    Repo(id: 1, installationID: 987, name: "alpha", fullName: "acme/alpha", owner: "acme", visibility: .public, defaultBranch: "main", archived: false),
                    Repo(id: 2, installationID: 987, name: "beta", fullName: "acme/beta", owner: "acme", visibility: .private, defaultBranch: "main", archived: false)
                ]
            )
        ),
        loadConfigItemsUseCase: LoadConfigItemsUseCase(configRepository: configRepository),
        saveConfigItemUseCase: SaveConfigItemUseCase(configRepository: configRepository),
        deleteConfigItemUseCase: DeleteConfigItemUseCase(configRepository: configRepository),
        syncConfigItemsUseCase: SyncConfigItemsUseCase(syncExecutor: StubSummarySyncExecutor(summary: summary)),
        authSettingsStore: FileAuthSettingsStore(baseDirectoryOverride: authRoot),
        shouldRestoreSessionOnLaunch: false
    )
    let viewModel = AppViewModel(container: container)

    await viewModel.restoreSession()
    viewModel.selectedRepoIDs = [1, 2]
    viewModel.syncSelected()
    try await Task.sleep(for: .milliseconds(50))

    #expect(viewModel.syncSummary == summary)
    #expect(viewModel.syncSummary?.successCount == 1)
    #expect(viewModel.syncSummary?.failureCount == 1)
}

@Test("GitHub 安装访问令牌会在仓库 API 前完成交换")
func githubInstallationTokenExchangeIsUsedForActionsAPI() async throws {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockURLProtocol.self]
    let urlSession = URLSession(configuration: configuration)
    let sessionStore = makeSessionStore(
        accessToken: "ghu_user_token",
        tokenType: "bearer",
        installations: [GitHubInstallation(id: 987, accountLogin: "octo-org", accountType: "Organization")]
    )
    let authRepository = GitHubAuthRepository(
        configurationLoader: GitHubAuthConfigurationLoader(
            environment: [
                "GITHUB_APP_ID": "3241508",
                "GITHUB_APP_CLIENT_ID": "Iv1.testclient",
                "GITHUB_APP_CLIENT_SECRET": "secret-123",
                "GITHUB_APP_SLUG": "secretvarsync",
                "GITHUB_APP_PRIVATE_KEY_PATH": "/tmp/secretvarsync.pem"
            ]
        ),
        oauthService: GitHubOAuthService(
            session: urlSession,
            appJWTProvider: { _ in "signed-app-jwt" }
        ),
        sessionStore: sessionStore,
        session: urlSession
    )
    let client = GitHubActionsAPIClient(authRepository: authRepository, session: urlSession)
    let requestRecorder = RequestRecorder()

    MockURLProtocol.requestHandler = { request in
        let url = try #require(request.url)
        requestRecorder.append(
            RecordedRequest(
                url: request.url,
                headers: request.allHTTPHeaderFields ?? [:],
                body: readRequestBody(from: request)
            )
        )

        if url.host == "api.github.com", url.path == "/user" {
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, #"{"login":"octocat"}"#.data(using: .utf8)!)
        }

        if url.host == "api.github.com", url.path == "/user/installations" {
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = #"{"installations":[{"id":987,"account":{"login":"octo-org","type":"Organization"}}]}"#.data(using: .utf8)!
            return (response, data)
        }

        if url.host == "api.github.com", url.path == "/app/installations/987/access_tokens" {
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer signed-app-jwt")
            let response = HTTPURLResponse(url: url, statusCode: 201, httpVersion: nil, headerFields: nil)!
            let data = #"{"token":"ghs_installation_token","expires_at":"2099-01-01T00:00:00Z"}"#.data(using: .utf8)!
            return (response, data)
        }

        if url.host == "api.github.com", url.path == "/repos/octocat/secretsync/actions/secrets/public-key" {
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer ghs_installation_token")
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = #"{"key_id":"kid","key":"pub"}"#.data(using: .utf8)!
            return (response, data)
        }

        throw URLError(.unsupportedURL)
    }
    defer { MockURLProtocol.requestHandler = nil }

    let publicKey = try await client.fetchRepositoryPublicKey(owner: "octocat", repo: "secretsync", installationID: 987)
    let requests = requestRecorder.snapshot()

    #expect(publicKey.keyID == "kid")
    #expect(publicKey.key == "pub")
    #expect(requests.contains(where: { $0.url?.path == "/app/installations/987/access_tokens" }))
    #expect(requests.contains(where: { $0.url?.path == "/repos/octocat/secretsync/actions/secrets/public-key" }))
}

@Test("GitHub 安装列表会分页拉取并合并缓存")
func githubAuthRepositoryPaginatesInstallationsBeforeCaching() async throws {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockURLProtocol.self]
    let urlSession = URLSession(configuration: configuration)
    let sessionStore = makeSessionStore(
        accessToken: "ghu_user_token",
        tokenType: "bearer"
    )
    let authRepository = GitHubAuthRepository(
        configurationLoader: GitHubAuthConfigurationLoader(
            environment: [
                "GITHUB_APP_ID": "3241508",
                "GITHUB_APP_CLIENT_ID": "Iv1.testclient",
                "GITHUB_APP_CLIENT_SECRET": "secret-123",
                "GITHUB_APP_SLUG": "secretvarsync",
                "GITHUB_APP_PRIVATE_KEY_PATH": "/tmp/secretvarsync.pem"
            ]
        ),
        oauthService: GitHubOAuthService(session: urlSession),
        sessionStore: sessionStore,
        session: urlSession
    )
    let requestRecorder = RequestRecorder()

    MockURLProtocol.requestHandler = { request in
        let url = try #require(request.url)
        requestRecorder.append(
            RecordedRequest(
                url: request.url,
                headers: request.allHTTPHeaderFields ?? [:],
                body: readRequestBody(from: request)
            )
        )

        if url.host == "api.github.com", url.path == "/user" {
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, #"{"login":"octocat"}"#.data(using: .utf8)!)
        }

        if url.host == "api.github.com", url.path == "/user/installations" {
            let page = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "page" })?
                .value

            let payload: String
            switch page {
            case "1":
                payload = #"{"total_count":2,"installations":[{"id":101,"account":{"login":"octo-org","type":"Organization"}}]}"#
            case "2":
                payload = #"{"total_count":2,"installations":[{"id":202,"account":{"login":"octocat","type":"User"}}]}"#
            default:
                payload = #"{"total_count":2,"installations":[]}"#
            }

            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, payload.data(using: .utf8)!)
        }

        throw URLError(.unsupportedURL)
    }
    defer { MockURLProtocol.requestHandler = nil }

    let session = try await authRepository.currentSession()
    let storedInstallations = try await authRepository.accessibleInstallations()
    let requests = requestRecorder.snapshot()
    let installationPages = requests.compactMap { request -> String? in
        guard let url = request.url, url.host == "api.github.com", url.path == "/user/installations" else {
            return nil
        }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "page" })?
            .value
    }

    #expect(session?.installations.count == 2)
    #expect(storedInstallations.count == 2)
    #expect(Set(installationPages) == Set(["1", "2"]))
}

@Test("GitHub 同步客户端可完成 Secret 与 Variable 上传")
func githubSyncClientUploadsSecretsAndVariables() async throws {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockURLProtocol.self]
    let urlSession = URLSession(configuration: configuration)
    let sessionStore = makeSessionStore(
        accessToken: "ghu_user_token",
        tokenType: "bearer",
        installations: [GitHubInstallation(id: 987, accountLogin: "octo-org", accountType: "Organization")]
    )
    let authRepository = GitHubAuthRepository(
        configurationLoader: GitHubAuthConfigurationLoader(
            environment: [
                "GITHUB_APP_ID": "3241508",
                "GITHUB_APP_CLIENT_ID": "Iv1.testclient",
                "GITHUB_APP_CLIENT_SECRET": "secret-123",
                "GITHUB_APP_SLUG": "secretvarsync",
                "GITHUB_APP_PRIVATE_KEY_PATH": "/tmp/secretvarsync.pem"
            ]
        ),
        oauthService: GitHubOAuthService(
            session: urlSession,
            appJWTProvider: { _ in "signed-app-jwt" }
        ),
        sessionStore: sessionStore,
        session: urlSession
    )
    let requestRecorder = RequestRecorder()
    let executor = GitHubSyncExecutor(
        client: GitHubActionsAPIClient(authRepository: authRepository, session: urlSession),
        encryptionService: StubEncryptionService(encryptedValue: "ZW5jcnlwdGVk")
    )

    MockURLProtocol.requestHandler = { request in
        let url = try #require(request.url)
        requestRecorder.append(
            RecordedRequest(
                url: request.url,
                headers: request.allHTTPHeaderFields ?? [:],
                body: readRequestBody(from: request)
            )
        )

        if url.host == "api.github.com", url.path == "/user" {
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, #"{"login":"octocat"}"#.data(using: .utf8)!)
        }
        if url.host == "api.github.com", url.path == "/user/installations" {
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = #"{"installations":[{"id":987,"account":{"login":"octo-org","type":"Organization"}}]}"#.data(using: .utf8)!
            return (response, data)
        }
        if url.host == "api.github.com", url.path == "/app/installations/987/access_tokens" {
            let response = HTTPURLResponse(url: url, statusCode: 201, httpVersion: nil, headerFields: nil)!
            let data = #"{"token":"ghs_installation_token","expires_at":"2099-01-01T00:00:00Z"}"#.data(using: .utf8)!
            return (response, data)
        }
        if url.host == "api.github.com", url.path == "/repos/octocat/secretsync/actions/secrets/public-key" {
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = #"{"key_id":"kid","key":"cHVibGljLWtleQ=="}"#.data(using: .utf8)!
            return (response, data)
        }
        if url.host == "api.github.com", url.path == "/repos/octocat/secretsync/actions/secrets/API_TOKEN" {
            let response = HTTPURLResponse(url: url, statusCode: 201, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        if url.host == "api.github.com", url.path == "/repos/octocat/secretsync/actions/variables/IMAGE_TAG" {
            let response = HTTPURLResponse(url: url, statusCode: 204, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        throw URLError(.unsupportedURL)
    }
    defer { MockURLProtocol.requestHandler = nil }

    let summary = try await executor.sync(
        SyncRequest(
            repos: [Repo(id: 42, installationID: 987, name: "secretsync", fullName: "octocat/secretsync", owner: "octocat", visibility: .private, defaultBranch: "main", archived: false)],
            items: [
                ConfigItem(name: "API_TOKEN", type: .secret, value: "plain-secret"),
                ConfigItem(name: "IMAGE_TAG", type: .variable, value: "2026.04.01")
            ],
            overwriteExisting: true
        )
    )
    let requests = requestRecorder.snapshot()

    #expect(summary.successCount == 2)
    #expect(summary.failureCount == 0)
    #expect(requests.contains(where: { $0.url?.path == "/repos/octocat/secretsync/actions/secrets/API_TOKEN" && $0.body.contains("encrypted_value=ZW5jcnlwdGVk") == false }))
    #expect(requests.contains(where: { $0.url?.path == "/repos/octocat/secretsync/actions/variables/IMAGE_TAG" }))
}

@Test("GitHub 同步客户端会报告安装权限不足")
func githubSyncClientReportsInstallationPermissionDenied() async throws {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockURLProtocol.self]
    let urlSession = URLSession(configuration: configuration)
    let sessionStore = makeSessionStore(
        accessToken: "ghu_user_token",
        tokenType: "bearer",
        installations: [GitHubInstallation(id: 987, accountLogin: "octo-org", accountType: "Organization")]
    )
    let authRepository = GitHubAuthRepository(
        configurationLoader: GitHubAuthConfigurationLoader(
            environment: [
                "GITHUB_APP_ID": "3241508",
                "GITHUB_APP_CLIENT_ID": "Iv1.testclient",
                "GITHUB_APP_CLIENT_SECRET": "secret-123",
                "GITHUB_APP_SLUG": "secretvarsync",
                "GITHUB_APP_PRIVATE_KEY_PATH": "/tmp/secretvarsync.pem"
            ]
        ),
        oauthService: GitHubOAuthService(
            session: urlSession,
            appJWTProvider: { _ in "signed-app-jwt" }
        ),
        sessionStore: sessionStore,
        session: urlSession
    )
    let executor = GitHubSyncExecutor(
        client: GitHubActionsAPIClient(authRepository: authRepository, session: urlSession),
        encryptionService: StubEncryptionService(encryptedValue: "ZW5jcnlwdGVk")
    )

    MockURLProtocol.requestHandler = { request in
        let url = try #require(request.url)
        if url.host == "api.github.com", url.path == "/user" {
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, #"{"login":"octocat"}"#.data(using: .utf8)!)
        }
        if url.host == "api.github.com", url.path == "/user/installations" {
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, #"{"installations":[{"id":987,"account":{"login":"octo-org","type":"Organization"}}]}"#.data(using: .utf8)!)
        }
        if url.host == "api.github.com", url.path == "/app/installations/987/access_tokens" {
            return (HTTPURLResponse(url: url, statusCode: 201, httpVersion: nil, headerFields: nil)!, #"{"token":"ghs_installation_token","expires_at":"2099-01-01T00:00:00Z"}"#.data(using: .utf8)!)
        }
        if url.host == "api.github.com", url.path == "/repos/octocat/secretsync/actions/secrets/public-key" {
            return (HTTPURLResponse(url: url, statusCode: 403, httpVersion: nil, headerFields: nil)!, #"{"message":"Resource not accessible by integration"}"#.data(using: .utf8)!)
        }
        throw URLError(.unsupportedURL)
    }
    defer { MockURLProtocol.requestHandler = nil }

    let summary = try await executor.sync(
        SyncRequest(
            repos: [Repo(id: 42, installationID: 987, name: "secretsync", fullName: "octocat/secretsync", owner: "octocat", visibility: .private, defaultBranch: "main", archived: false)],
            items: [ConfigItem(name: "API_TOKEN", type: .secret, value: "plain-secret")],
            overwriteExisting: true
        )
    )

    #expect(summary.successCount == 0)
    #expect(summary.failureCount == 1)
    #expect(summary.results.first?.status == .failed("权限不足，或 GitHub App 未获得所需仓库权限"))
}

@Test("GitHub 同步客户端会报告仓库公钥异常")
func githubSyncClientReportsInvalidRepositoryPublicKey() async throws {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockURLProtocol.self]
    let urlSession = URLSession(configuration: configuration)
    let sessionStore = makeSessionStore(
        accessToken: "ghu_user_token",
        tokenType: "bearer",
        installations: [GitHubInstallation(id: 987, accountLogin: "octo-org", accountType: "Organization")]
    )
    let authRepository = GitHubAuthRepository(
        configurationLoader: GitHubAuthConfigurationLoader(
            environment: [
                "GITHUB_APP_ID": "3241508",
                "GITHUB_APP_CLIENT_ID": "Iv1.testclient",
                "GITHUB_APP_CLIENT_SECRET": "secret-123",
                "GITHUB_APP_SLUG": "secretvarsync",
                "GITHUB_APP_PRIVATE_KEY_PATH": "/tmp/secretvarsync.pem"
            ]
        ),
        oauthService: GitHubOAuthService(
            session: urlSession,
            appJWTProvider: { _ in "signed-app-jwt" }
        ),
        sessionStore: sessionStore,
        session: urlSession
    )
    let executor = GitHubSyncExecutor(
        client: GitHubActionsAPIClient(authRepository: authRepository, session: urlSession),
        encryptionService: GitHubSecretEncryptionService()
    )

    MockURLProtocol.requestHandler = { request in
        let url = try #require(request.url)
        if url.host == "api.github.com", url.path == "/user" {
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, #"{"login":"octocat"}"#.data(using: .utf8)!)
        }
        if url.host == "api.github.com", url.path == "/user/installations" {
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, #"{"installations":[{"id":987,"account":{"login":"octo-org","type":"Organization"}}]}"#.data(using: .utf8)!)
        }
        if url.host == "api.github.com", url.path == "/app/installations/987/access_tokens" {
            return (HTTPURLResponse(url: url, statusCode: 201, httpVersion: nil, headerFields: nil)!, #"{"token":"ghs_installation_token","expires_at":"2099-01-01T00:00:00Z"}"#.data(using: .utf8)!)
        }
        if url.host == "api.github.com", url.path == "/repos/octocat/secretsync/actions/secrets/public-key" {
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, #"{"key_id":"kid","key":"not-base64"}"#.data(using: .utf8)!)
        }
        throw URLError(.unsupportedURL)
    }
    defer { MockURLProtocol.requestHandler = nil }

    let summary = try await executor.sync(
        SyncRequest(
            repos: [Repo(id: 42, installationID: 987, name: "secretsync", fullName: "octocat/secretsync", owner: "octocat", visibility: .private, defaultBranch: "main", archived: false)],
            items: [ConfigItem(name: "API_TOKEN", type: .secret, value: "plain-secret")],
            overwriteExisting: true
        )
    )

    #expect(summary.successCount == 0)
    #expect(summary.failureCount == 1)
    #expect(summary.results.first?.status == .failed("GitHub 仓库公钥不是有效的 Base64"))
}

@Test("GitHub 同步客户端会报告变量上传失败")
func githubSyncClientReportsVariableUploadFailure() async throws {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockURLProtocol.self]
    let urlSession = URLSession(configuration: configuration)
    let sessionStore = makeSessionStore(
        accessToken: "ghu_user_token",
        tokenType: "bearer",
        installations: [GitHubInstallation(id: 987, accountLogin: "octo-org", accountType: "Organization")]
    )
    let authRepository = GitHubAuthRepository(
        configurationLoader: GitHubAuthConfigurationLoader(
            environment: [
                "GITHUB_APP_ID": "3241508",
                "GITHUB_APP_CLIENT_ID": "Iv1.testclient",
                "GITHUB_APP_CLIENT_SECRET": "secret-123",
                "GITHUB_APP_SLUG": "secretvarsync",
                "GITHUB_APP_PRIVATE_KEY_PATH": "/tmp/secretvarsync.pem"
            ]
        ),
        oauthService: GitHubOAuthService(
            session: urlSession,
            appJWTProvider: { _ in "signed-app-jwt" }
        ),
        sessionStore: sessionStore,
        session: urlSession
    )
    let executor = GitHubSyncExecutor(
        client: GitHubActionsAPIClient(authRepository: authRepository, session: urlSession),
        encryptionService: StubEncryptionService(encryptedValue: "ZW5jcnlwdGVk")
    )

    MockURLProtocol.requestHandler = { request in
        let url = try #require(request.url)
        if url.host == "api.github.com", url.path == "/user" {
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, #"{"login":"octocat"}"#.data(using: .utf8)!)
        }
        if url.host == "api.github.com", url.path == "/user/installations" {
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, #"{"installations":[{"id":987,"account":{"login":"octo-org","type":"Organization"}}]}"#.data(using: .utf8)!)
        }
        if url.host == "api.github.com", url.path == "/app/installations/987/access_tokens" {
            return (HTTPURLResponse(url: url, statusCode: 201, httpVersion: nil, headerFields: nil)!, #"{"token":"ghs_installation_token","expires_at":"2099-01-01T00:00:00Z"}"#.data(using: .utf8)!)
        }
        if url.host == "api.github.com", url.path == "/repos/octocat/secretsync/actions/variables/IMAGE_TAG" {
            return (HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!, #"{"message":"not found"}"#.data(using: .utf8)!)
        }
        if url.host == "api.github.com", url.path == "/repos/octocat/secretsync/actions/variables" {
            return (HTTPURLResponse(url: url, statusCode: 422, httpVersion: nil, headerFields: nil)!, #"{"message":"Validation Failed"}"#.data(using: .utf8)!)
        }
        throw URLError(.unsupportedURL)
    }
    defer { MockURLProtocol.requestHandler = nil }

    let summary = try await executor.sync(
        SyncRequest(
            repos: [Repo(id: 42, installationID: 987, name: "secretsync", fullName: "octocat/secretsync", owner: "octocat", visibility: .private, defaultBranch: "main", archived: false)],
            items: [ConfigItem(name: "IMAGE_TAG", type: .variable, value: "2026.04.01")],
            overwriteExisting: true
        )
    )

    #expect(summary.successCount == 0)
    #expect(summary.failureCount == 1)
    #expect(summary.results.first?.status == .failed("请求校验失败：{\"message\":\"Validation Failed\"}"))
}

@Test("SQLite 仓库会持久化 Secret")
func sqliteConfigRepositoryPersistsItems() async throws {
    let databaseURL = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString)
        .appending(path: "config.sqlite3")
    let repository = try SQLiteConfigRepository(databaseURL: databaseURL)

    let secret = try await repository.save(
        draft: ConfigItemDraft(name: "VPS_KEY", type: .secret, value: "super-secret", description: "")
    )

    let items = try await repository.listItems()

    #expect(items.count == 1)
    #expect(items.contains(where: { $0.id == secret.id && $0.value == "super-secret" }))
}

@Test("认证配置会写入并读回本地文件")
func authSettingsStoreRoundTrip() throws {
    let fileManager = FileManager.default
    let root = fileManager.temporaryDirectory.appending(path: UUID().uuidString)
    try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
    let store = FileAuthSettingsStore(baseDirectoryOverride: root)
    let draft = GitHubAuthSettingsDraft(
        appID: "3241508",
        clientID: "client-id",
        clientSecret: "client-secret",
        slug: "secretvarsync",
        privateKeyPath: "/tmp/secretvarsync.pem",
        callbackPath: "oauth/callback"
    )

    try store.saveDraft(draft)
    let loaded = try store.loadDraft()
    let rawData = try Data(contentsOf: try store.settingsLocation())
    let rawText = try #require(String(data: rawData, encoding: .utf8))

    #expect(loaded?.appID == "3241508")
    #expect(loaded?.clientID == "client-id")
    #expect(loaded?.clientSecret == "client-secret")
    #expect(loaded?.slug == "secretvarsync")
    #expect(loaded?.privateKeyPath == "/tmp/secretvarsync.pem")
    #expect(loaded?.callbackPath == "/oauth/callback")
    #expect(rawText.contains("client-secret"))
}

@Test("覆盖目录下保存的 GitHub App 配置可被加载并生成真实授权地址")
func authConfigurationLoaderReadsOverrideDirectoryForAuthorizationURL() throws {
    let fileManager = FileManager.default
    let root = fileManager.temporaryDirectory.appending(path: UUID().uuidString)
    try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
    let store = FileAuthSettingsStore(baseDirectoryOverride: root)
    try store.saveDraft(
        GitHubAuthSettingsDraft(
            appID: "3241508",
            clientID: "Iv23liPcbu7jrAGxIylq",
            clientSecret: "client-secret",
            slug: "secretvarsync",
            privateKeyPath: "/tmp/secretvarsync.pem",
            callbackPath: "/oauth/callback"
        )
    )

    let loader = GitHubAuthConfigurationLoader(
        environment: [:],
        baseDirectoryOverride: root
    )
    let configuration = try #require(try loader.loadIfAvailable())
    let context = try GitHubOAuthService().prepareAuthorization(configuration: configuration)
    let components = try #require(URLComponents(url: context.authorizationURL, resolvingAgainstBaseURL: false))
    let queryMap = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })

    #expect(configuration.clientID == "Iv23liPcbu7jrAGxIylq")
    #expect(queryMap["client_id"] == "Iv23liPcbu7jrAGxIylq")
    #expect(context.redirectURI.hasSuffix("/oauth/callback"))
}

@Test("认证配置会把旧版文件中的 Client Secret 迁移为本地存储格式")
func authSettingsStoreMigratesLegacyClientSecret() throws {
    let fileManager = FileManager.default
    let root = fileManager.temporaryDirectory.appending(path: UUID().uuidString)
    try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
    let store = FileAuthSettingsStore(baseDirectoryOverride: root)
    let legacy = GitHubAuthConfiguration(
        appID: "3241508",
        clientID: "legacy-client-id",
        clientSecret: "legacy-client-secret",
        slug: "secretvarsync",
        privateKeyPath: "/tmp/secretvarsync.pem",
        callbackPath: "/oauth/callback"
    )
    let legacyData = try JSONEncoder().encode(legacy)
    let settingsURL = try store.settingsLocation()
    try FileManager.default.createDirectory(at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try legacyData.write(to: settingsURL)

    let loaded = try store.loadDraft()
    let rawData = try Data(contentsOf: settingsURL)
    let rawText = try #require(String(data: rawData, encoding: .utf8))

    #expect(loaded?.clientSecret == "legacy-client-secret")
    #expect(rawText.contains("legacy-client-secret"))
}

private func waitForAuthorizationURL(recorder: ProgressRecorder) async throws -> URL {
    let deadline = Date().addingTimeInterval(5)
    while Date() < deadline {
        let events = await recorder.snapshot()
        if let url = events.compactMap({
            if case let .openingBrowser(url) = $0 { return url }
            return nil
        }).last {
            return url
        }
        try await Task.sleep(for: .milliseconds(50))
    }

    throw AppError.infrastructure("测试未等到 GitHub App 授权地址")
}

private func makeSessionStore(
    accessToken: String = "",
    tokenType: String = "bearer",
    installations: [GitHubInstallation] = []
) -> FileAuthSessionStore {
    let stateURL = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString)
        .appending(path: "auth-session.json")
    let store = FileAuthSessionStore(stateURL: stateURL)
    if !accessToken.isEmpty {
        try? store.save(
            StoredGitHubAuthSessionState(
                accessToken: accessToken,
                refreshToken: nil,
                expiresAt: nil,
                refreshTokenExpiresAt: nil,
                tokenType: tokenType,
                username: nil,
                installations: installations,
                installationTokens: [:]
            )
        )
    }
    return store
}

private func waitForCallbackReady(recorder: ProgressRecorder) async throws -> Int {
    let deadline = Date().addingTimeInterval(5)
    while Date() < deadline {
        let events = await recorder.snapshot()
        if let port = events.compactMap({
            if case let .waitingForBrowserCallback(port) = $0 { return port }
            return nil
        }).last {
            return port
        }
        try await Task.sleep(for: .milliseconds(50))
    }

    throw AppError.infrastructure("测试未等到 GitHub App 本地回调监听就绪")
}

private func triggerLoopbackCallback(redirectURI: String, state: String) async throws {
    let baseURL = try #require(URL(string: redirectURI))
    var components = try #require(URLComponents(url: baseURL, resolvingAgainstBaseURL: false))
    components.queryItems = [
        URLQueryItem(name: "code", value: "test-code"),
        URLQueryItem(name: "state", value: state)
    ]

    let callbackURL = try #require(components.url)
    var lastError: Error?
    for _ in 0 ..< 60 {
        do {
            _ = try await URLSession.shared.data(from: callbackURL)
            return
        } catch {
            lastError = error
            try await Task.sleep(for: .milliseconds(50))
        }
    }

    throw lastError ?? AppError.infrastructure("测试未能触发 loopback 回调")
}

private func readRequestBody(from request: URLRequest) -> String {
    if let body = request.httpBody, let raw = String(data: body, encoding: .utf8) {
        return raw
    }

    guard let stream = request.httpBodyStream else {
        return ""
    }

    stream.open()
    defer { stream.close() }

    var data = Data()
    let bufferSize = 1024
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }

    while stream.hasBytesAvailable {
        let count = stream.read(buffer, maxLength: bufferSize)
        if count <= 0 { break }
        data.append(buffer, count: count)
    }

    return String(data: data, encoding: .utf8) ?? ""
}

@Test("未打开编辑器时同步范围应为过滤结果而非默认首项")
@MainActor
func appViewModelSyncScopeUsesFilteredItemsWhenEditorClosed() async throws {
    let first = ConfigItem(name: "FIRST_SECRET", type: .secret, value: "a")
    let second = ConfigItem(name: "SECOND_SECRET", type: .secret, value: "b")
    let repository = InMemoryConfigRepository(seedItems: [first, second])
    let settingsRoot = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: settingsRoot, withIntermediateDirectories: true)
    let container = AppContainer(
        signInUseCase: SignInUseCase(authRepository: StubAuthRepository(restoredSession: nil)),
        fetchRepositoriesUseCase: FetchRepositoriesUseCase(repositoryCatalog: StubRepositoryCatalog(repositories: SampleData.repos)),
        loadConfigItemsUseCase: LoadConfigItemsUseCase(configRepository: repository),
        saveConfigItemUseCase: SaveConfigItemUseCase(configRepository: repository),
        deleteConfigItemUseCase: DeleteConfigItemUseCase(configRepository: repository),
        syncConfigItemsUseCase: SyncConfigItemsUseCase(syncExecutor: ImmediateSuccessSyncExecutor()),
        authSettingsStore: FileAuthSettingsStore(baseDirectoryOverride: settingsRoot),
        shouldRestoreSessionOnLaunch: false,
        shouldUsePlaintextSecretEditorForAutomation: true
    )
    let viewModel = AppViewModel(container: container)

    await viewModel.loadInitialState(restoreSession: false)

    #expect(viewModel.selectedConfigItemID == nil)
    #expect(viewModel.showConfigEditor == false)
    #expect(viewModel.selectedItemsForSync.count == 2)
}

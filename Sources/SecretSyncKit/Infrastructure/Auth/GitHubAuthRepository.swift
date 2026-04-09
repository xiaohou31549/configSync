import Foundation

public actor GitHubAuthRepository: AuthRepository {
    private let configurationLoader: GitHubAuthConfigurationLoader
    private let oauthService: GitHubOAuthService
    private let sessionStore: FileAuthSessionStore
    private let session: URLSession
    private let decoder = JSONDecoder()
    private var cachedState: StoredGitHubAuthSessionState?

    init(
        configurationLoader: GitHubAuthConfigurationLoader? = nil,
        oauthService: GitHubOAuthService = GitHubOAuthService(),
        sessionStore: FileAuthSessionStore = FileAuthSessionStore(),
        session: URLSession = .shared
    ) {
        self.configurationLoader = configurationLoader ?? GitHubAuthConfigurationLoader()
        self.oauthService = oauthService
        self.sessionStore = sessionStore
        self.session = session
    }

    public func currentSession() async throws -> UserSession? {
        guard var bundle = try loadUserTokenBundle() else {
            return nil
        }

        if bundle.isExpired {
            guard bundle.refreshTokenUsable, let refreshToken = bundle.refreshToken else {
                if bundle.refreshToken == nil {
                    return try await validateSession(bundle)
                }

                try clearStoredCredentials()
                return nil
            }

            let configuration = try configurationLoader.requireConfiguration()
            bundle = try await oauthService.refreshToken(refreshToken, configuration: configuration)
            try saveUserTokenBundle(bundle)
            await persist(progress: .refreshingToken, handler: nil)
        }

        return try await validateSession(bundle)
    }

    public func signIn(progress: AuthProgressHandler?) async throws -> UserSession {
        let configuration = try configurationLoader.requireConfiguration()
        await persist(progress: .preparingBrowserLogin, handler: progress)
        let context = try oauthService.prepareAuthorization(configuration: configuration)
        await persist(progress: .openingBrowser(context.authorizationURL), handler: progress)
        await persist(progress: .waitingForBrowserCallback(port: context.port), handler: progress)

        let callback = try await oauthService.awaitAuthorizationCallback(context: context)
        await persist(progress: .exchangingCode, handler: progress)
        let bundle = try await oauthService.exchangeCode(callback, context: context, configuration: configuration)
        try saveUserTokenBundle(bundle)

        await persist(progress: .loadingProfile, handler: progress)
        let session = try await validateSession(bundle)
        await persist(progress: .completed(username: session.username), handler: progress)
        return session
    }

    public func signOut() async throws {
        try clearStoredCredentials()
    }

    public func validAccessToken() async throws -> String {
        try await validInstallationAccessToken(for: nil)
    }

    public func validUserAccessToken() async throws -> String {
        guard let session = try await currentSession() else {
            throw AppError.infrastructure("当前没有可用的 GitHub 登录会话")
        }
        return session.accessToken
    }

    public func accessibleInstallations() async throws -> [GitHubInstallation] {
        if let stored = try loadInstallations(), !stored.isEmpty {
            _ = try await currentSession()
            return stored
        }

        guard let bundle = try loadUserTokenBundle() else {
            return []
        }

        let installations = try await fetchInstallations(accessToken: bundle.accessToken)
        try saveInstallations(installations)
        return installations
    }

    public func validInstallationAccessToken(for installationID: Int?) async throws -> String {
        let session = try await currentSession()
        guard let session else {
            throw AppError.infrastructure("当前没有可用的 GitHub 登录会话")
        }

        let installations = session.installations
        guard !installations.isEmpty else {
            throw AppError.infrastructure("当前 GitHub App 尚未安装到任何账号或组织")
        }

        let resolvedInstallationID = installationID ?? installations[0].id
        if var cached = try loadInstallationTokenBundle(for: resolvedInstallationID) {
            if cached.isExpired {
                let configuration = try configurationLoader.requireConfiguration()
                cached = try await oauthService.createInstallationAccessToken(
                    installationID: resolvedInstallationID,
                    configuration: configuration
                )
                try saveInstallationTokenBundle(cached, for: resolvedInstallationID)
            }
            return cached.accessToken
        }

        let configuration = try configurationLoader.requireConfiguration()
        let bundle = try await oauthService.createInstallationAccessToken(
            installationID: resolvedInstallationID,
            configuration: configuration
        )
        try saveInstallationTokenBundle(bundle, for: resolvedInstallationID)
        return bundle.accessToken
    }

    private func fetchUsername(accessToken: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.github.com/user")!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("SecretSync", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AppError.infrastructure("GitHub 用户资料响应无效")
        }

        guard (200 ..< 300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "未知错误"
            throw AppError.infrastructure("拉取 GitHub 用户资料失败：HTTP \(http.statusCode) \(message)")
        }

        let payload = try decoder.decode(UserProfileResponse.self, from: data)
        return payload.login
    }

    private func validateSession(_ bundle: TokenBundle) async throws -> UserSession {
        let username = try await fetchUsername(accessToken: bundle.accessToken)
        let installations = try await fetchInstallations(accessToken: bundle.accessToken)
        guard !installations.isEmpty else {
            throw AppError.infrastructure("GitHub App 尚未安装到任何账号或组织，请先完成安装")
        }
        var state = try loadSessionState(bundle: bundle) ?? StoredGitHubAuthSessionState(
            accessToken: bundle.accessToken,
            refreshToken: bundle.refreshToken,
            expiresAt: bundle.expiresAt?.iso8601String,
            refreshTokenExpiresAt: bundle.refreshTokenExpiresAt?.iso8601String,
            tokenType: bundle.tokenType,
            username: nil,
            installations: [],
            installationTokens: [:]
        )
        state.username = username
        state.installations = installations
        try sessionStore.save(state)
        return UserSession(
            username: username,
            accessToken: bundle.accessToken,
            tokenBundle: bundle,
            installations: installations
        )
    }

    private func fetchInstallations(accessToken: String) async throws -> [GitHubInstallation] {
        var page = 1
        var installations: [GitHubInstallation] = []
        var expectedTotalCount: Int?

        while true {
            var components = URLComponents(string: "https://api.github.com/user/installations")!
            components.queryItems = [
                URLQueryItem(name: "per_page", value: "100"),
                URLQueryItem(name: "page", value: String(page))
            ]
            guard let url = components.url else {
                throw AppError.infrastructure("GitHub 安装列表地址构造失败")
            }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
            request.setValue("SecretSync", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw AppError.infrastructure("GitHub 安装列表响应无效")
            }

            guard (200 ..< 300).contains(http.statusCode) else {
                let message = String(data: data, encoding: .utf8) ?? "未知错误"
                throw AppError.infrastructure("拉取 GitHub App 安装列表失败：HTTP \(http.statusCode) \(message)")
            }

            let payload = try decoder.decode(UserInstallationsResponse.self, from: data)
            expectedTotalCount = expectedTotalCount ?? payload.totalCount
            installations.append(contentsOf: payload.installations.map(\.domainModel))

            let currentPageCount = payload.installations.count
            if currentPageCount == 0 {
                break
            }

            if let expectedTotalCount, installations.count >= expectedTotalCount {
                break
            }

            if expectedTotalCount == nil, currentPageCount < 100 {
                break
            }

            page += 1
        }

        return installations
    }

    private func loadUserTokenBundle() throws -> TokenBundle? {
        guard let state = try loadPersistedState() else {
            return nil
        }

        return TokenBundle(
            accessToken: state.accessToken,
            refreshToken: state.refreshToken,
            expiresAt: state.expiresAt.flatMap(Date.fromISO8601),
            refreshTokenExpiresAt: state.refreshTokenExpiresAt.flatMap(Date.fromISO8601),
            tokenType: state.tokenType
        )
    }

    private func saveUserTokenBundle(_ bundle: TokenBundle) throws {
        var state = try loadPersistedState() ?? StoredGitHubAuthSessionState(
            accessToken: bundle.accessToken,
            refreshToken: bundle.refreshToken,
            expiresAt: bundle.expiresAt?.iso8601String,
            refreshTokenExpiresAt: bundle.refreshTokenExpiresAt?.iso8601String,
            tokenType: bundle.tokenType,
            username: nil,
            installations: [],
            installationTokens: [:]
        )
        state.accessToken = bundle.accessToken
        state.refreshToken = bundle.refreshToken
        state.expiresAt = bundle.expiresAt?.iso8601String
        state.refreshTokenExpiresAt = bundle.refreshTokenExpiresAt?.iso8601String
        state.tokenType = bundle.tokenType
        try persistState(state)
    }

    private func loadInstallations() throws -> [GitHubInstallation]? {
        try loadPersistedState()?.installations
    }

    private func saveInstallations(_ installations: [GitHubInstallation]) throws {
        var state = try loadPersistedState() ?? StoredGitHubAuthSessionState(
            accessToken: "",
            refreshToken: nil,
            expiresAt: nil,
            refreshTokenExpiresAt: nil,
            tokenType: "bearer",
            username: nil,
            installations: [],
            installationTokens: [:]
        )
        state.installations = installations
        try persistState(state)
    }

    private func loadInstallationTokenBundle(for installationID: Int) throws -> TokenBundle? {
        guard let state = try loadPersistedState(),
              let stored = state.installationTokens[String(installationID)] else {
            return nil
        }
        return TokenBundle(
            accessToken: stored.accessToken,
            refreshToken: nil,
            expiresAt: stored.expiresAt.flatMap(Date.fromISO8601),
            refreshTokenExpiresAt: nil,
            tokenType: "bearer"
        )
    }

    private func saveInstallationTokenBundle(_ bundle: TokenBundle, for installationID: Int) throws {
        var state = try loadPersistedState() ?? StoredGitHubAuthSessionState(
            accessToken: "",
            refreshToken: nil,
            expiresAt: nil,
            refreshTokenExpiresAt: nil,
            tokenType: "bearer",
            username: nil,
            installations: [],
            installationTokens: [:]
        )
        state.installationTokens[String(installationID)] = StoredInstallationTokenBundle(
            accessToken: bundle.accessToken,
            expiresAt: bundle.expiresAt?.iso8601String
        )
        try persistState(state)
    }

    private func clearStoredCredentials() throws {
        cachedState = nil
        try sessionStore.remove()
    }

    private func loadSessionState(bundle: TokenBundle) throws -> StoredGitHubAuthSessionState? {
        if var state = try loadPersistedState() {
            state.accessToken = bundle.accessToken
            state.refreshToken = bundle.refreshToken
            state.expiresAt = bundle.expiresAt?.iso8601String
            state.refreshTokenExpiresAt = bundle.refreshTokenExpiresAt?.iso8601String
            state.tokenType = bundle.tokenType
            return state
        }
        return nil
    }

    private func loadPersistedState() throws -> StoredGitHubAuthSessionState? {
        if let cachedState {
            return cachedState
        }
        let loaded = try sessionStore.load()
        cachedState = loaded
        return loaded
    }

    private func persistState(_ state: StoredGitHubAuthSessionState) throws {
        cachedState = state
        try sessionStore.save(state)
    }

    private func persist(progress: GitHubAuthProgress, handler: AuthProgressHandler?) async {
        await handler?(progress)
    }
}

private struct UserProfileResponse: Decodable {
    let login: String
}

private struct UserInstallationsResponse: Decodable {
    let totalCount: Int?
    let installations: [Installation]

    private enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case installations
    }

    struct Installation: Decodable {
        let id: Int
        let account: Account

        struct Account: Decodable {
            let login: String
            let type: String
        }

        var domainModel: GitHubInstallation {
            GitHubInstallation(id: id, accountLogin: account.login, accountType: account.type)
        }
    }
}

private extension Date {
    static func fromISO8601(_ raw: String) -> Date? {
        ISO8601DateFormatter().date(from: raw)
    }

    var iso8601String: String {
        ISO8601DateFormatter().string(from: self)
    }
}

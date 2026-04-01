import Foundation

public actor GitHubAuthRepository: AuthRepository {
    private let configurationLoader: GitHubAuthConfigurationLoader
    private let oauthService: GitHubOAuthService
    private let keychainStore: KeychainStore
    private let session: URLSession
    private let decoder = JSONDecoder()

    private let userAccessTokenKey = "auth.github.userAccessToken"
    private let userRefreshTokenKey = "auth.github.userRefreshToken"
    private let userExpiresAtKey = "auth.github.userExpiresAt"
    private let userRefreshExpiresAtKey = "auth.github.userRefreshExpiresAt"
    private let usernameKey = "auth.github.username"
    private let userTokenTypeKey = "auth.github.userTokenType"
    private let installationsKey = "auth.github.installations"

    init(
        configurationLoader: GitHubAuthConfigurationLoader? = nil,
        oauthService: GitHubOAuthService = GitHubOAuthService(),
        keychainStore: KeychainStore = KeychainStore(),
        session: URLSession = .shared
    ) {
        self.configurationLoader = configurationLoader ?? GitHubAuthConfigurationLoader(keychainStore: keychainStore)
        self.oauthService = oauthService
        self.keychainStore = keychainStore
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
        try keychainStore.save(username, for: usernameKey)
        try saveInstallations(installations)
        return UserSession(
            username: username,
            accessToken: bundle.accessToken,
            tokenBundle: bundle,
            installations: installations
        )
    }

    private func fetchInstallations(accessToken: String) async throws -> [GitHubInstallation] {
        var request = URLRequest(url: URL(string: "https://api.github.com/user/installations")!)
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
        return payload.installations.map(\.domainModel)
    }

    private func loadUserTokenBundle() throws -> TokenBundle? {
        guard let accessToken = try keychainStore.load(for: userAccessTokenKey) else {
            return nil
        }

        let refreshToken = try keychainStore.load(for: userRefreshTokenKey)
        let expiresAt = try keychainStore.load(for: userExpiresAtKey).flatMap(Date.fromISO8601)
        let refreshTokenExpiresAt = try keychainStore.load(for: userRefreshExpiresAtKey).flatMap(Date.fromISO8601)
        let tokenType = try keychainStore.load(for: userTokenTypeKey) ?? "bearer"

        return TokenBundle(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt,
            refreshTokenExpiresAt: refreshTokenExpiresAt,
            tokenType: tokenType
        )
    }

    private func saveUserTokenBundle(_ bundle: TokenBundle) throws {
        try keychainStore.save(bundle.accessToken, for: userAccessTokenKey)
        if let refreshToken = bundle.refreshToken {
            try keychainStore.save(refreshToken, for: userRefreshTokenKey)
        } else {
            try keychainStore.delete(for: userRefreshTokenKey)
        }

        if let expiresAt = bundle.expiresAt {
            try keychainStore.save(expiresAt.iso8601String, for: userExpiresAtKey)
        } else {
            try keychainStore.delete(for: userExpiresAtKey)
        }

        if let refreshTokenExpiresAt = bundle.refreshTokenExpiresAt {
            try keychainStore.save(refreshTokenExpiresAt.iso8601String, for: userRefreshExpiresAtKey)
        } else {
            try keychainStore.delete(for: userRefreshExpiresAtKey)
        }

        try keychainStore.save(bundle.tokenType, for: userTokenTypeKey)
    }

    private func loadInstallations() throws -> [GitHubInstallation]? {
        guard let raw = try keychainStore.load(for: installationsKey) else {
            return nil
        }
        return try JSONDecoder().decode([GitHubInstallation].self, from: Data(raw.utf8))
    }

    private func saveInstallations(_ installations: [GitHubInstallation]) throws {
        let data = try JSONEncoder().encode(installations)
        guard let raw = String(data: data, encoding: .utf8) else {
            throw AppError.infrastructure("安装列表编码失败")
        }
        try keychainStore.save(raw, for: installationsKey)
    }

    private func installationAccessTokenKey(for installationID: Int) -> String {
        "auth.github.installation.\(installationID).accessToken"
    }

    private func installationExpiresAtKey(for installationID: Int) -> String {
        "auth.github.installation.\(installationID).expiresAt"
    }

    private func loadInstallationTokenBundle(for installationID: Int) throws -> TokenBundle? {
        guard let accessToken = try keychainStore.load(for: installationAccessTokenKey(for: installationID)) else {
            return nil
        }
        let expiresAt = try keychainStore.load(for: installationExpiresAtKey(for: installationID)).flatMap(Date.fromISO8601)
        return TokenBundle(
            accessToken: accessToken,
            refreshToken: nil,
            expiresAt: expiresAt,
            refreshTokenExpiresAt: nil,
            tokenType: "bearer"
        )
    }

    private func saveInstallationTokenBundle(_ bundle: TokenBundle, for installationID: Int) throws {
        try keychainStore.save(bundle.accessToken, for: installationAccessTokenKey(for: installationID))
        if let expiresAt = bundle.expiresAt {
            try keychainStore.save(expiresAt.iso8601String, for: installationExpiresAtKey(for: installationID))
        } else {
            try keychainStore.delete(for: installationExpiresAtKey(for: installationID))
        }
    }

    private func clearStoredCredentials() throws {
        let installations = try loadInstallations() ?? []
        try keychainStore.delete(for: userAccessTokenKey)
        try keychainStore.delete(for: userRefreshTokenKey)
        try keychainStore.delete(for: userExpiresAtKey)
        try keychainStore.delete(for: userRefreshExpiresAtKey)
        try keychainStore.delete(for: usernameKey)
        try keychainStore.delete(for: userTokenTypeKey)
        try keychainStore.delete(for: installationsKey)
        for installation in installations {
            try keychainStore.delete(for: installationAccessTokenKey(for: installation.id))
            try keychainStore.delete(for: installationExpiresAtKey(for: installation.id))
        }
    }

    private func persist(progress: GitHubAuthProgress, handler: AuthProgressHandler?) async {
        await handler?(progress)
    }
}

private struct UserProfileResponse: Decodable {
    let login: String
}

private struct UserInstallationsResponse: Decodable {
    let installations: [Installation]

    private enum CodingKeys: String, CodingKey {
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

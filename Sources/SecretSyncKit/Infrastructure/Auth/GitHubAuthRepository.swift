import Foundation

public actor GitHubAuthRepository: AuthRepository {
    private let configurationLoader: GitHubAuthConfigurationLoader
    private let deviceFlowService: GitHubDeviceFlowService
    private let keychainStore: KeychainStore
    private let session: URLSession
    private let decoder = JSONDecoder()

    private let accessTokenKey = "auth.github.accessToken"
    private let refreshTokenKey = "auth.github.refreshToken"
    private let expiresAtKey = "auth.github.expiresAt"
    private let refreshExpiresAtKey = "auth.github.refreshExpiresAt"
    private let usernameKey = "auth.github.username"
    private let tokenTypeKey = "auth.github.tokenType"

    init(
        configurationLoader: GitHubAuthConfigurationLoader = GitHubAuthConfigurationLoader(),
        deviceFlowService: GitHubDeviceFlowService = GitHubDeviceFlowService(),
        keychainStore: KeychainStore = KeychainStore(),
        session: URLSession = .shared
    ) {
        self.configurationLoader = configurationLoader
        self.deviceFlowService = deviceFlowService
        self.keychainStore = keychainStore
        self.session = session
    }

    public func currentSession() async throws -> UserSession? {
        guard var bundle = try loadTokenBundle() else {
            return nil
        }

        if bundle.isExpired {
            guard bundle.refreshTokenUsable, let refreshToken = bundle.refreshToken else {
                try clearStoredCredentials()
                return nil
            }

            let configuration = try configurationLoader.requireConfiguration()
            bundle = try await deviceFlowService.refreshToken(refreshToken, configuration: configuration)
            try saveTokenBundle(bundle)
            await persist(progress: .refreshingToken, handler: nil)
        }

        let username = try await fetchUsername(accessToken: bundle.accessToken)
        try keychainStore.save(username, for: usernameKey)
        return UserSession(username: username, accessToken: bundle.accessToken, tokenBundle: bundle)
    }

    public func signIn(progress: AuthProgressHandler?) async throws -> UserSession {
        let configuration = try configurationLoader.requireConfiguration()
        await persist(progress: .requestingCode, handler: progress)
        let authorization = try await deviceFlowService.requestDeviceAuthorization(configuration: configuration)
        await persist(progress: .waitingForUser(authorization), handler: progress)

        var interval = max(authorization.interval, 5)

        while Date() < authorization.expiresAt {
            await persist(progress: .polling(nextInterval: interval), handler: progress)
            try await Task.sleep(for: .seconds(interval))

            let result = try await deviceFlowService.exchangeDeviceCode(authorization, configuration: configuration)
            switch result {
            case let .success(bundle):
                try saveTokenBundle(bundle)
                await persist(progress: .loadingProfile, handler: progress)
                let username = try await fetchUsername(accessToken: bundle.accessToken)
                try keychainStore.save(username, for: usernameKey)
                let session = UserSession(username: username, accessToken: bundle.accessToken, tokenBundle: bundle)
                await persist(progress: .completed(username: username), handler: progress)
                return session
            case let .pending(errorCode):
                switch errorCode {
                case "authorization_pending":
                    continue
                case "slow_down":
                    interval += 5
                case "expired_token":
                    throw AppError.infrastructure("Device Code 已过期，请重新发起登录")
                case "access_denied":
                    throw AppError.infrastructure("用户取消了 GitHub 授权")
                default:
                    throw AppError.infrastructure("GitHub 授权失败：\(errorCode)")
                }
            }
        }

        throw AppError.infrastructure("GitHub 授权超时，请重新发起登录")
    }

    public func signOut() async throws {
        try clearStoredCredentials()
    }

    public func validAccessToken() async throws -> String {
        guard let session = try await currentSession() else {
            throw AppError.infrastructure("当前没有可用的 GitHub 登录会话")
        }
        return session.accessToken
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

    private func loadTokenBundle() throws -> TokenBundle? {
        guard let accessToken = try keychainStore.load(for: accessTokenKey) else {
            return nil
        }

        let refreshToken = try keychainStore.load(for: refreshTokenKey)
        let expiresAt = try keychainStore.load(for: expiresAtKey).flatMap(Date.fromISO8601)
        let refreshTokenExpiresAt = try keychainStore.load(for: refreshExpiresAtKey).flatMap(Date.fromISO8601)
        let tokenType = try keychainStore.load(for: tokenTypeKey) ?? "bearer"

        return TokenBundle(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt,
            refreshTokenExpiresAt: refreshTokenExpiresAt,
            tokenType: tokenType
        )
    }

    private func saveTokenBundle(_ bundle: TokenBundle) throws {
        try keychainStore.save(bundle.accessToken, for: accessTokenKey)
        if let refreshToken = bundle.refreshToken {
            try keychainStore.save(refreshToken, for: refreshTokenKey)
        } else {
            try keychainStore.delete(for: refreshTokenKey)
        }

        if let expiresAt = bundle.expiresAt {
            try keychainStore.save(expiresAt.iso8601String, for: expiresAtKey)
        } else {
            try keychainStore.delete(for: expiresAtKey)
        }

        if let refreshTokenExpiresAt = bundle.refreshTokenExpiresAt {
            try keychainStore.save(refreshTokenExpiresAt.iso8601String, for: refreshExpiresAtKey)
        } else {
            try keychainStore.delete(for: refreshExpiresAtKey)
        }

        try keychainStore.save(bundle.tokenType, for: tokenTypeKey)
    }

    private func clearStoredCredentials() throws {
        try keychainStore.delete(for: accessTokenKey)
        try keychainStore.delete(for: refreshTokenKey)
        try keychainStore.delete(for: expiresAtKey)
        try keychainStore.delete(for: refreshExpiresAtKey)
        try keychainStore.delete(for: usernameKey)
        try keychainStore.delete(for: tokenTypeKey)
    }

    private func persist(progress: GitHubAuthProgress, handler: AuthProgressHandler?) async {
        await handler?(progress)
    }
}

private struct UserProfileResponse: Decodable {
    let login: String
}

private extension Date {
    static func fromISO8601(_ raw: String) -> Date? {
        ISO8601DateFormatter().date(from: raw)
    }

    var iso8601String: String {
        ISO8601DateFormatter().string(from: self)
    }
}

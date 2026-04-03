import Foundation

public struct GitHubAuthConfiguration: Codable, Equatable, Sendable {
    public let appID: String
    public let clientID: String
    public let clientSecret: String
    public let slug: String
    public let privateKeyPath: String
    public let callbackPath: String

    public init(
        appID: String,
        clientID: String,
        clientSecret: String,
        slug: String,
        privateKeyPath: String,
        callbackPath: String = "/oauth/callback",
    ) {
        self.appID = appID
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.slug = slug
        self.privateKeyPath = privateKeyPath
        self.callbackPath = callbackPath
    }
}

enum GitHubAuthSecretKeys {
    static let clientSecret = "auth.github.appClientSecret"
}

struct StoredGitHubAuthConfiguration: Codable, Equatable, Sendable {
    let appID: String
    let clientID: String
    let slug: String
    let privateKeyPath: String
    let callbackPath: String
    let clientSecret: String?

    init(
        appID: String,
        clientID: String,
        slug: String,
        privateKeyPath: String,
        callbackPath: String,
        clientSecret: String? = nil
    ) {
        self.appID = appID
        self.clientID = clientID
        self.slug = slug
        self.privateKeyPath = privateKeyPath
        self.callbackPath = callbackPath
        self.clientSecret = clientSecret
    }

    func resolvedConfiguration(clientSecret: String?) -> GitHubAuthConfiguration? {
        let resolvedSecret = clientSecret ?? self.clientSecret
        guard let resolvedSecret, !resolvedSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return GitHubAuthConfiguration(
            appID: appID,
            clientID: clientID,
            clientSecret: resolvedSecret,
            slug: slug,
            privateKeyPath: privateKeyPath,
            callbackPath: callbackPath
        )
    }
}

public struct GitHubAuthConfigurationLoader: Sendable {
    private let environment: [String: String]
    private let baseDirectoryOverride: URL?
    private let keychainStore: KeychainStore
    private let decoder = JSONDecoder()

    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        baseDirectoryOverride: URL? = nil,
        keychainStore: KeychainStore = KeychainStore()
    ) {
        self.environment = environment
        self.baseDirectoryOverride = baseDirectoryOverride
        self.keychainStore = keychainStore
    }

    public func loadIfAvailable() throws -> GitHubAuthConfiguration? {
        if let appID = environment["GITHUB_APP_ID"],
           let clientID = environment["GITHUB_APP_CLIENT_ID"] ?? environment["GITHUB_CLIENT_ID"],
           let clientSecret = environment["GITHUB_APP_CLIENT_SECRET"] ?? environment["GITHUB_CLIENT_SECRET"],
           let slug = environment["GITHUB_APP_SLUG"],
           let privateKeyPath = environment["GITHUB_APP_PRIVATE_KEY_PATH"],
           !appID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return GitHubAuthConfiguration(
                appID: appID,
                clientID: clientID,
                clientSecret: clientSecret,
                slug: slug,
                privateKeyPath: privateKeyPath,
                callbackPath: environment["GITHUB_CALLBACK_PATH"] ?? "/oauth/callback"
            )
        }

        for path in candidatePaths() {
            guard FileManager.default.fileExists(atPath: path.path()) else { continue }
            let data = try Data(contentsOf: path)
            if let stored = try? decoder.decode(StoredGitHubAuthConfiguration.self, from: data),
               let configuration = stored.resolvedConfiguration(
                   clientSecret: try keychainStore.load(for: GitHubAuthSecretKeys.clientSecret)
               ) {
                return configuration
            }

            if let legacy = try? decoder.decode(GitHubAuthConfiguration.self, from: data) {
                return legacy
            }
        }

        return nil
    }

    public func requireConfiguration() throws -> GitHubAuthConfiguration {
        guard let configuration = try loadIfAvailable() else {
            throw AppError.infrastructure("缺少 GitHub App 配置。请设置环境变量 GITHUB_APP_ID / GITHUB_APP_CLIENT_ID / GITHUB_APP_CLIENT_SECRET / GITHUB_APP_SLUG / GITHUB_APP_PRIVATE_KEY_PATH，或在应用内保存 GitHub App 配置与 Client Secret")
        }
        return configuration
    }

    private func candidatePaths() -> [URL] {
        let currentDirectory = URL(filePath: FileManager.default.currentDirectoryPath)
        let appSupport = baseDirectoryOverride ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appending(path: "SecretSync", directoryHint: .isDirectory)
        let appSupportFile = appSupport?.appending(path: "auth.json")

        return [
            currentDirectory.appending(path: "SecretSync.auth.json"),
            currentDirectory.appending(path: ".secretsync").appending(path: "auth.json"),
            appSupportFile
        ].compactMap { $0 }
    }
}

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

public enum GitHubAuthConfigurationSource: Equatable, Sendable {
    case environment
    case localFile
    case bundledApp
}

public struct ResolvedGitHubAuthConfiguration: Equatable, Sendable {
    public let configuration: GitHubAuthConfiguration
    public let source: GitHubAuthConfigurationSource

    public init(configuration: GitHubAuthConfiguration, source: GitHubAuthConfigurationSource) {
        self.configuration = configuration
        self.source = source
    }
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

    func resolvedConfiguration() -> GitHubAuthConfiguration? {
        guard let clientSecret, !clientSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return GitHubAuthConfiguration(
            appID: appID,
            clientID: clientID,
            clientSecret: clientSecret,
            slug: slug,
            privateKeyPath: privateKeyPath,
            callbackPath: callbackPath
        )
    }
}

public struct GitHubAuthConfigurationLoader: Sendable {
    private let environment: [String: String]
    private let baseDirectoryOverride: URL?
    private let bundledConfigurationData: Data?
    private let bundledResourceResolver: @Sendable (String) -> URL?
    private let decoder = JSONDecoder()

    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        baseDirectoryOverride: URL? = nil,
        bundledConfigurationData: Data? = Bundle.main.url(forResource: "BundledGitHubApp", withExtension: "json").flatMap { try? Data(contentsOf: $0) },
        bundledResourceResolver: @escaping @Sendable (String) -> URL? = { resourceName in
            let resourceURL = URL(filePath: resourceName)
            let pathExtension = resourceURL.pathExtension
            let resourceBaseName = resourceURL.deletingPathExtension().lastPathComponent
            let normalizedExtension = pathExtension.isEmpty ? nil : pathExtension
            return Bundle.main.url(forResource: resourceBaseName, withExtension: normalizedExtension)
        }
    ) {
        self.environment = environment
        self.baseDirectoryOverride = baseDirectoryOverride
        self.bundledConfigurationData = bundledConfigurationData
        self.bundledResourceResolver = bundledResourceResolver
    }

    public func loadIfAvailable() throws -> GitHubAuthConfiguration? {
        try loadResolvedConfiguration()?.configuration
    }

    public func loadResolvedConfiguration() throws -> ResolvedGitHubAuthConfiguration? {
        if let appID = environment["GITHUB_APP_ID"],
           let clientID = environment["GITHUB_APP_CLIENT_ID"] ?? environment["GITHUB_CLIENT_ID"],
           let clientSecret = environment["GITHUB_APP_CLIENT_SECRET"] ?? environment["GITHUB_CLIENT_SECRET"],
           let slug = environment["GITHUB_APP_SLUG"],
           let privateKeyPath = environment["GITHUB_APP_PRIVATE_KEY_PATH"],
           !appID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ResolvedGitHubAuthConfiguration(
                configuration: GitHubAuthConfiguration(
                    appID: appID,
                    clientID: clientID,
                    clientSecret: clientSecret,
                    slug: slug,
                    privateKeyPath: privateKeyPath,
                    callbackPath: environment["GITHUB_CALLBACK_PATH"] ?? "/oauth/callback"
                ),
                source: .environment
            )
        }

        for path in candidatePaths() {
            guard FileManager.default.fileExists(atPath: path.path()) else { continue }
            let data = try Data(contentsOf: path)
            if let stored = try? decoder.decode(StoredGitHubAuthConfiguration.self, from: data),
               let configuration = stored.resolvedConfiguration() {
                return ResolvedGitHubAuthConfiguration(configuration: configuration, source: .localFile)
            }

            if let legacy = try? decoder.decode(GitHubAuthConfiguration.self, from: data) {
                return ResolvedGitHubAuthConfiguration(configuration: legacy, source: .localFile)
            }
        }

        if let bundledConfigurationData {
            let bundled = try decoder.decode(BundledGitHubAuthConfiguration.self, from: bundledConfigurationData)
            guard let configuration = bundled.resolvedConfiguration(resourceResolver: bundledResourceResolver) else {
                throw AppError.infrastructure("应用内置 GitHub App 配置无效")
            }
            return ResolvedGitHubAuthConfiguration(configuration: configuration, source: .bundledApp)
        }

        return nil
    }

    public func requireConfiguration() throws -> GitHubAuthConfiguration {
        guard let configuration = try loadIfAvailable() else {
            throw AppError.infrastructure("缺少 GitHub App 配置。请设置环境变量 GITHUB_APP_ID / GITHUB_APP_CLIENT_ID / GITHUB_APP_CLIENT_SECRET / GITHUB_APP_SLUG / GITHUB_APP_PRIVATE_KEY_PATH，提供应用内置 `BundledGitHubApp.json` 与私钥资源，或在应用内保存 GitHub App 覆盖配置与 Client Secret")
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

private struct BundledGitHubAuthConfiguration: Decodable {
    let appID: String
    let clientID: String
    let clientSecret: String
    let slug: String
    let privateKeyPath: String?
    let privateKeyResource: String?
    let callbackPath: String?

    func resolvedConfiguration(resourceResolver: (String) -> URL?) -> GitHubAuthConfiguration? {
        let resolvedPrivateKeyPath: String?
        if let privateKeyPath, !privateKeyPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            resolvedPrivateKeyPath = privateKeyPath
        } else if let privateKeyResource,
                  let resolvedURL = resourceResolver(privateKeyResource) {
            resolvedPrivateKeyPath = resolvedURL.path()
        } else {
            resolvedPrivateKeyPath = nil
        }

        guard let resolvedPrivateKeyPath,
              !appID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !clientSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !slug.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return GitHubAuthConfiguration(
            appID: appID,
            clientID: clientID,
            clientSecret: clientSecret,
            slug: slug,
            privateKeyPath: resolvedPrivateKeyPath,
            callbackPath: callbackPath?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? callbackPath! : "/oauth/callback"
        )
    }
}

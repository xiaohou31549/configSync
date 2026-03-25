import Foundation

public struct GitHubAuthConfiguration: Decodable, Equatable, Sendable {
    public let clientID: String
    public let clientSecret: String
    public let appName: String
    public let callbackPath: String
    public let scopes: [String]

    public init(
        clientID: String,
        clientSecret: String,
        appName: String = "SecretSync",
        callbackPath: String = "/oauth/callback",
        scopes: [String] = ["repo", "read:user"]
    ) {
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.appName = appName
        self.callbackPath = callbackPath
        self.scopes = scopes
    }
}

public struct GitHubAuthConfigurationLoader {
    private let environment: [String: String]
    private let fileManager: FileManager
    private let decoder = JSONDecoder()

    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) {
        self.environment = environment
        self.fileManager = fileManager
    }

    public func loadIfAvailable() throws -> GitHubAuthConfiguration? {
        if let clientID = environment["GITHUB_APP_CLIENT_ID"] ?? environment["GITHUB_CLIENT_ID"],
           let clientSecret = environment["GITHUB_APP_CLIENT_SECRET"] ?? environment["GITHUB_CLIENT_SECRET"],
           !clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return GitHubAuthConfiguration(
                clientID: clientID,
                clientSecret: clientSecret,
                callbackPath: environment["GITHUB_CALLBACK_PATH"] ?? "/oauth/callback",
                scopes: (environment["GITHUB_AUTH_SCOPES"] ?? "repo read:user")
                    .split(separator: " ")
                    .map(String.init)
            )
        }

        for path in candidatePaths() {
            guard fileManager.fileExists(atPath: path.path()) else { continue }
            let data = try Data(contentsOf: path)
            return try decoder.decode(GitHubAuthConfiguration.self, from: data)
        }

        return nil
    }

    public func requireConfiguration() throws -> GitHubAuthConfiguration {
        guard let configuration = try loadIfAvailable() else {
            throw AppError.infrastructure("缺少 GitHub OAuth 配置。请设置环境变量 GITHUB_CLIENT_ID / GITHUB_CLIENT_SECRET，或在项目根目录创建 SecretSync.auth.json")
        }
        return configuration
    }

    private func candidatePaths() -> [URL] {
        let currentDirectory = URL(filePath: fileManager.currentDirectoryPath)
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appending(path: "SecretSync")
            .appending(path: "auth.json")

        return [
            currentDirectory.appending(path: "SecretSync.auth.json"),
            currentDirectory.appending(path: ".secretsync").appending(path: "auth.json"),
            appSupport
        ].compactMap { $0 }
    }
}

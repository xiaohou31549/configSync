import Foundation

public struct GitHubAuthConfiguration: Decodable, Equatable, Sendable {
    public let clientID: String
    public let appName: String

    public init(clientID: String, appName: String = "SecretSync") {
        self.clientID = clientID
        self.appName = appName
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
           !clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return GitHubAuthConfiguration(clientID: clientID)
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
            throw AppError.infrastructure("缺少 GitHub App client_id。请设置环境变量 GITHUB_APP_CLIENT_ID，或在项目根目录创建 SecretSync.auth.json")
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

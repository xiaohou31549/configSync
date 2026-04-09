import Foundation

struct StoredInstallationTokenBundle: Codable, Sendable {
    let accessToken: String
    let expiresAt: String?
}

struct StoredGitHubAuthSessionState: Codable, Sendable {
    var accessToken: String
    var refreshToken: String?
    var expiresAt: String?
    var refreshTokenExpiresAt: String?
    var tokenType: String
    var username: String?
    var installations: [GitHubInstallation]
    var installationTokens: [String: StoredInstallationTokenBundle]
}

struct FileAuthSessionStore: Sendable {
    private let stateURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(stateURL: URL? = nil) {
        if let stateURL {
            self.stateURL = stateURL
        } else {
            let appSupport = try? FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            self.stateURL = appSupport?
                .appending(path: "SecretSync", directoryHint: .isDirectory)
                .appending(path: "auth-session.json") ?? URL(filePath: FileManager.default.currentDirectoryPath).appending(path: "SecretSync.auth-session.json")
        }
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func load() throws -> StoredGitHubAuthSessionState? {
        guard FileManager.default.fileExists(atPath: stateURL.path()) else {
            return nil
        }
        let data = try Data(contentsOf: stateURL)
        return try decoder.decode(StoredGitHubAuthSessionState.self, from: data)
    }

    func save(_ state: StoredGitHubAuthSessionState) throws {
        try FileManager.default.createDirectory(at: stateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try encoder.encode(state)
        try data.write(to: stateURL, options: .atomic)
    }

    func remove() throws {
        if FileManager.default.fileExists(atPath: stateURL.path()) {
            try FileManager.default.removeItem(at: stateURL)
        }
    }
}

import Foundation

public struct GitHubAuthSettingsDraft: Equatable, Sendable {
    public var clientID: String
    public var clientSecret: String
    public var callbackPath: String
    public var scopes: String

    public init(
        clientID: String = "",
        clientSecret: String = "",
        callbackPath: String = "/oauth/callback",
        scopes: String = "repo read:user"
    ) {
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.callbackPath = callbackPath
        self.scopes = scopes
    }

    public var isValid: Bool {
        !clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !clientSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !callbackPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

public protocol AuthSettingsStore: Sendable {
    func loadDraft() throws -> GitHubAuthSettingsDraft?
    func saveDraft(_ draft: GitHubAuthSettingsDraft) throws
    func removeDraft() throws
    func settingsLocation() throws -> URL
}

public struct FileAuthSettingsStore: AuthSettingsStore {
    private let baseDirectoryOverride: URL?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(baseDirectoryOverride: URL? = nil) {
        self.baseDirectoryOverride = baseDirectoryOverride
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    public func loadDraft() throws -> GitHubAuthSettingsDraft? {
        let url = try settingsLocation()
        guard FileManager.default.fileExists(atPath: url.path()) else {
            return nil
        }
        let data = try Data(contentsOf: url)
        let configuration = try decoder.decode(GitHubAuthConfiguration.self, from: data)
        return GitHubAuthSettingsDraft(
            clientID: configuration.clientID,
            clientSecret: configuration.clientSecret,
            callbackPath: configuration.callbackPath,
            scopes: configuration.scopes.joined(separator: " ")
        )
    }

    public func saveDraft(_ draft: GitHubAuthSettingsDraft) throws {
        guard draft.isValid else {
            throw AppError.validation("请填写完整的 Client ID、Client Secret 和 Callback Path")
        }

        let normalizedScopes = draft.scopes
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)

        let configuration = GitHubAuthConfiguration(
            clientID: draft.clientID.trimmingCharacters(in: .whitespacesAndNewlines),
            clientSecret: draft.clientSecret.trimmingCharacters(in: .whitespacesAndNewlines),
            callbackPath: normalizeCallbackPath(draft.callbackPath),
            scopes: normalizedScopes.isEmpty ? ["repo", "read:user"] : normalizedScopes
        )

        let url = try settingsLocation()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try encoder.encode(configuration)
        try data.write(to: url, options: Data.WritingOptions.atomic)
    }

    public func removeDraft() throws {
        let url = try settingsLocation()
        guard FileManager.default.fileExists(atPath: url.path()) else { return }
        try FileManager.default.removeItem(at: url)
    }

    public func settingsLocation() throws -> URL {
        let baseDirectory = if let baseDirectoryOverride {
            baseDirectoryOverride
        } else {
            try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        }
        return baseDirectory
            .appending(path: "SecretSync", directoryHint: .isDirectory)
            .appending(path: "auth.json")
    }

    private func normalizeCallbackPath(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("/") ? trimmed : "/\(trimmed)"
    }
}

import Foundation

public struct GitHubAuthSettingsDraft: Equatable, Sendable {
    public var appID: String
    public var clientID: String
    public var clientSecret: String
    public var slug: String
    public var privateKeyPath: String
    public var callbackPath: String

    public init(
        appID: String = "",
        clientID: String = "",
        clientSecret: String = "",
        slug: String = "",
        privateKeyPath: String = "",
        callbackPath: String = "/oauth/callback",
    ) {
        self.appID = appID
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.slug = slug
        self.privateKeyPath = privateKeyPath
        self.callbackPath = callbackPath
    }

    public var isValid: Bool {
        !appID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !clientSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !slug.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !privateKeyPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
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
        let result = try loadStoredConfiguration(from: data)
        let configuration = result.configuration
        if result.wasMigratedFromLegacyFile {
            let sanitized = StoredGitHubAuthConfiguration(
                appID: configuration.appID,
                clientID: configuration.clientID,
                slug: configuration.slug,
                privateKeyPath: configuration.privateKeyPath,
                callbackPath: configuration.callbackPath,
                clientSecret: configuration.clientSecret
            )
            let sanitizedData = try encoder.encode(sanitized)
            try sanitizedData.write(to: url, options: Data.WritingOptions.atomic)
        }
        return GitHubAuthSettingsDraft(
            appID: configuration.appID,
            clientID: configuration.clientID,
            clientSecret: configuration.clientSecret,
            slug: configuration.slug,
            privateKeyPath: configuration.privateKeyPath,
            callbackPath: configuration.callbackPath
        )
    }

    public func saveDraft(_ draft: GitHubAuthSettingsDraft) throws {
        guard draft.isValid else {
            throw AppError.validation("请填写完整的 App ID、Client ID、Client Secret、Slug、私钥路径和回调地址")
        }

        let configuration = GitHubAuthConfiguration(
            appID: draft.appID.trimmingCharacters(in: .whitespacesAndNewlines),
            clientID: draft.clientID.trimmingCharacters(in: .whitespacesAndNewlines),
            clientSecret: draft.clientSecret.trimmingCharacters(in: .whitespacesAndNewlines),
            slug: draft.slug.trimmingCharacters(in: .whitespacesAndNewlines),
            privateKeyPath: draft.privateKeyPath.trimmingCharacters(in: .whitespacesAndNewlines),
            callbackPath: normalizeCallbackValue(draft.callbackPath)
        )
        let storedConfiguration = StoredGitHubAuthConfiguration(
            appID: configuration.appID,
            clientID: configuration.clientID,
            slug: configuration.slug,
            privateKeyPath: configuration.privateKeyPath,
            callbackPath: configuration.callbackPath,
            clientSecret: configuration.clientSecret
        )

        let url = try settingsLocation()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try encoder.encode(storedConfiguration)
        try data.write(to: url, options: Data.WritingOptions.atomic)
    }

    public func removeDraft() throws {
        let url = try settingsLocation()
        if FileManager.default.fileExists(atPath: url.path()) {
            try FileManager.default.removeItem(at: url)
        }
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
        if baseDirectoryOverride != nil {
            return baseDirectory.appending(path: "auth.json")
        }
        return baseDirectory
            .appending(path: "SecretSync", directoryHint: .isDirectory)
            .appending(path: "auth.json")
    }

    private func normalizeCallbackValue(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("://") {
            return trimmed
        }
        return trimmed.hasPrefix("/") ? trimmed : "/\(trimmed)"
    }

    private func loadStoredConfiguration(from data: Data) throws -> (configuration: GitHubAuthConfiguration, wasMigratedFromLegacyFile: Bool) {
        if let stored = try? decoder.decode(StoredGitHubAuthConfiguration.self, from: data) {
            if let configuration = stored.resolvedConfiguration() {
                return (configuration, false)
            }
        }

        if let legacy = try? decoder.decode(GitHubAuthConfiguration.self, from: data) {
            return (legacy, true)
        }

        throw AppError.infrastructure("本地 GitHub App 配置格式无效")
    }
}

import Foundation

public struct UserSession: Equatable, Sendable {
    public let username: String
    public let accessToken: String
    public let tokenBundle: TokenBundle
    public let installations: [GitHubInstallation]

    public init(
        username: String,
        accessToken: String,
        tokenBundle: TokenBundle,
        installations: [GitHubInstallation] = []
    ) {
        self.username = username
        self.accessToken = accessToken
        self.tokenBundle = tokenBundle
        self.installations = installations
    }
}

public struct GitHubInstallation: Codable, Equatable, Sendable, Identifiable {
    public let id: Int
    public let accountLogin: String
    public let accountType: String

    public init(id: Int, accountLogin: String, accountType: String) {
        self.id = id
        self.accountLogin = accountLogin
        self.accountType = accountType
    }
}

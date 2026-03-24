import Foundation

public struct UserSession: Equatable, Sendable {
    public let username: String
    public let accessToken: String
    public let tokenBundle: TokenBundle

    public init(username: String, accessToken: String, tokenBundle: TokenBundle) {
        self.username = username
        self.accessToken = accessToken
        self.tokenBundle = tokenBundle
    }
}

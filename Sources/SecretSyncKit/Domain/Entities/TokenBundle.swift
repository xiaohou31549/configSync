import Foundation

public struct TokenBundle: Equatable, Sendable {
    public let accessToken: String
    public let refreshToken: String?
    public let expiresAt: Date?
    public let refreshTokenExpiresAt: Date?
    public let tokenType: String

    public init(
        accessToken: String,
        refreshToken: String?,
        expiresAt: Date?,
        refreshTokenExpiresAt: Date?,
        tokenType: String
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.refreshTokenExpiresAt = refreshTokenExpiresAt
        self.tokenType = tokenType
    }

    public var isExpired: Bool {
        guard let expiresAt else { return false }
        return expiresAt <= Date().addingTimeInterval(60)
    }

    public var refreshTokenUsable: Bool {
        guard let refreshToken else { return false }
        guard let refreshTokenExpiresAt else { return !refreshToken.isEmpty }
        return !refreshToken.isEmpty && refreshTokenExpiresAt > Date().addingTimeInterval(60)
    }
}

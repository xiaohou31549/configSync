import Foundation

public actor MockGitHubAuthRepository: AuthRepository {
    private var session: UserSession?

    public init() {}

    public func currentSession() async throws -> UserSession? {
        session
    }

    public func signIn(progress: AuthProgressHandler?) async throws -> UserSession {
        await progress?(.requestingCode)
        try await Task.sleep(for: .milliseconds(900))
        let authorization = DeviceAuthorization(
            deviceCode: "mock-device-code",
            userCode: "ABCD-EFGH",
            verificationURI: URL(string: "https://github.com/login/device")!,
            expiresAt: Date().addingTimeInterval(900),
            interval: 5
        )
        await progress?(.waitingForUser(authorization))
        await progress?(.polling(nextInterval: 5))
        try await Task.sleep(for: .milliseconds(600))
        let bundle = TokenBundle(
            accessToken: "mock-device-flow-token",
            refreshToken: "mock-refresh-token",
            expiresAt: Date().addingTimeInterval(28_800),
            refreshTokenExpiresAt: Date().addingTimeInterval(15_897_600),
            tokenType: "bearer"
        )
        let newSession = UserSession(username: "tough", accessToken: bundle.accessToken, tokenBundle: bundle)
        session = newSession
        await progress?(.completed(username: newSession.username))
        return newSession
    }

    public func signOut() async throws {
        session = nil
    }
}

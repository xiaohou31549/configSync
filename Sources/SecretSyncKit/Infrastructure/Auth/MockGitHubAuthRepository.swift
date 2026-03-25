import Foundation

public actor MockGitHubAuthRepository: AuthRepository {
    private var session: UserSession?

    public init() {}

    public func currentSession() async throws -> UserSession? {
        session
    }

    public func signIn(progress: AuthProgressHandler?) async throws -> UserSession {
        await progress?(.preparingBrowserLogin)
        try await Task.sleep(for: .milliseconds(900))
        let authorizationURL = URL(string: "https://github.com/login/oauth/authorize?client_id=mock")!
        let context = OAuthAuthorizationContext(
            authorizationURL: authorizationURL,
            redirectURI: "http://127.0.0.1:45678/oauth/callback",
            callbackPath: "/oauth/callback",
            port: 45678,
            state: "mock-state",
            codeVerifier: "mock-verifier"
        )
        await progress?(.openingBrowser(context.authorizationURL))
        await progress?(.waitingForBrowserCallback(port: context.port))
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

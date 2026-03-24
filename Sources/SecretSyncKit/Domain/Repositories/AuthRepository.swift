import Foundation

public typealias AuthProgressHandler = @Sendable (GitHubAuthProgress) async -> Void

public protocol AuthRepository: Sendable {
    func currentSession() async throws -> UserSession?
    func signIn(progress: AuthProgressHandler?) async throws -> UserSession
    func signOut() async throws
}

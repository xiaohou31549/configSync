import Foundation

public struct SignInUseCase: Sendable {
    private let authRepository: AuthRepository

    public init(authRepository: AuthRepository) {
        self.authRepository = authRepository
    }

    public func execute(progress: AuthProgressHandler? = nil) async throws -> UserSession {
        try await authRepository.signIn(progress: progress)
    }

    public func restoreSession() async throws -> UserSession? {
        try await authRepository.currentSession()
    }

    public func signOut() async throws {
        try await authRepository.signOut()
    }
}

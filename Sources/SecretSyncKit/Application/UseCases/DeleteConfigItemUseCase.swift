import Foundation

public struct DeleteConfigItemUseCase: Sendable {
    private let configRepository: ConfigRepository

    public init(configRepository: ConfigRepository) {
        self.configRepository = configRepository
    }

    public func execute(id: UUID) async throws {
        try await configRepository.delete(id: id)
    }
}

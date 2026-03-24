import Foundation

public struct LoadConfigItemsUseCase: Sendable {
    private let configRepository: ConfigRepository

    public init(configRepository: ConfigRepository) {
        self.configRepository = configRepository
    }

    public func execute() async throws -> [ConfigItem] {
        try await configRepository.listItems()
            .sorted { $0.updatedAt > $1.updatedAt }
    }
}

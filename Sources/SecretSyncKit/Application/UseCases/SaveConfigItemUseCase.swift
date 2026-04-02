import Foundation

public struct SaveConfigItemUseCase: Sendable {
    private let configRepository: ConfigRepository

    public init(configRepository: ConfigRepository) {
        self.configRepository = configRepository
    }

    public func execute(_ draft: ConfigItemDraft) async throws -> ConfigItem {
        let normalized = ConfigItemDraft(
            id: draft.id,
            name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            type: draft.type,
            value: draft.value,
            description: draft.description.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        guard normalized.isValid else {
            throw AppError.validation("名称和值不能为空")
        }

        let existingItems = try await configRepository.listItems()
        let hasDuplicateName = existingItems.contains { item in
            item.type == normalized.type &&
            item.name == normalized.name &&
            item.id != normalized.id
        }

        guard !hasDuplicateName else {
            throw AppError.validation("已存在同名 Secret，请使用其他名称")
        }

        return try await configRepository.save(draft: normalized)
    }
}

import Foundation

public actor InMemoryConfigRepository: ConfigRepository {
    private var items: [ConfigItem]

    public init(seedItems: [ConfigItem] = []) {
        self.items = seedItems
    }

    public func listItems() async throws -> [ConfigItem] {
        items
    }

    public func save(draft: ConfigItemDraft) async throws -> ConfigItem {
        let now = Date()

        if let id = draft.id, let index = items.firstIndex(where: { $0.id == id }) {
            items[index].name = draft.name
            items[index].type = draft.type
            items[index].value = draft.value
            items[index].description = draft.description.isEmpty ? nil : draft.description
            items[index].updatedAt = now
            return items[index]
        }

        let newItem = ConfigItem(
            id: draft.id ?? UUID(),
            name: draft.name,
            type: draft.type,
            value: draft.value,
            description: draft.description.isEmpty ? nil : draft.description,
            createdAt: now,
            updatedAt: now
        )
        items.insert(newItem, at: 0)
        return newItem
    }

    public func delete(id: UUID) async throws {
        items.removeAll { $0.id == id }
    }
}

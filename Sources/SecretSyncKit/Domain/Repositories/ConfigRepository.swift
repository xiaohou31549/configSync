import Foundation

public protocol ConfigRepository: Sendable {
    func listItems() async throws -> [ConfigItem]
    func save(draft: ConfigItemDraft) async throws -> ConfigItem
    func delete(id: UUID) async throws
}

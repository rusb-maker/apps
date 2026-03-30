import Foundation
import SwiftData

@Model
class CardFolder {
    var id: UUID
    var name: String
    var parent: CardFolder?
    @Relationship(deleteRule: .cascade, inverse: \CardFolder.parent)
    var children: [CardFolder] = []
    var createdAt: Date

    init(id: UUID = UUID(), name: String, parent: CardFolder? = nil, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.parent = parent
        self.createdAt = createdAt
    }
}

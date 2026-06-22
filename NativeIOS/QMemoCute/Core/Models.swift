import Foundation
import SwiftUI

enum MemoCategory: String, CaseIterable, Codable, Identifiable {
    case life
    case todo
    case study
    case idea
    case diary

    var id: String { rawValue }

    var title: String {
        switch self {
        case .life: "生活"
        case .todo: "待办"
        case .study: "学习"
        case .idea: "灵感"
        case .diary: "心情"
        }
    }

    var iconAsset: String {
        switch self {
        case .life: "CategoryLife"
        case .todo: "CategoryTodo"
        case .study: "CategoryStudy"
        case .idea: "CategoryIdea"
        case .diary: "CategoryDiary"
        }
    }

    var stickerAsset: String {
        switch self {
        case .life: "StickerCamera"
        case .todo: "StickerChecklist"
        case .study: "StickerReading"
        case .idea: "StickerIdea"
        case .diary: "StickerFlower"
        }
    }

    var tint: Color {
        switch self {
        case .life: Theme.Colors.pink
        case .todo: Theme.Colors.cream
        case .study: Theme.Colors.sky
        case .idea: Theme.Colors.mint
        case .diary: Theme.Colors.lavender
        }
    }
}

struct MemoSticker: Identifiable, Codable, Equatable {
    var id: UUID
    var assetName: String
    var positionX: Double
    var positionY: Double
    var scale: Double
    var rotationDegrees: Double

    init(
        id: UUID = UUID(),
        assetName: String,
        positionX: Double,
        positionY: Double,
        scale: Double = 1,
        rotationDegrees: Double = 0
    ) {
        self.id = id
        self.assetName = assetName
        self.positionX = positionX
        self.positionY = positionY
        self.scale = scale
        self.rotationDegrees = rotationDegrees
    }
}

struct MemoTodoItem: Identifiable, Codable, Equatable {
    var id: UUID
    var text: String
    var isCompleted: Bool
    var createdAt: Date
    var reminderAt: Date?
    var isUrgent: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case text
        case isCompleted
        case createdAt
        case reminderAt
        case isUrgent
    }

    init(
        id: UUID = UUID(),
        text: String = "",
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        reminderAt: Date? = nil,
        isUrgent: Bool = false
    ) {
        self.id = id
        self.text = text
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.reminderAt = reminderAt
        self.isUrgent = isUrgent
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        reminderAt = try container.decodeIfPresent(Date.self, forKey: .reminderAt)
        isUrgent = try container.decodeIfPresent(Bool.self, forKey: .isUrgent) ?? false
    }
}

struct Memo: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var content: String
    var richContentData: Data?
    var category: MemoCategory
    var isPinned: Bool
    var createdAt: Date
    var updatedAt: Date
    var stickers: [MemoSticker]
    var todoItems: [MemoTodoItem]

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case content
        case richContentData
        case category
        case isPinned
        case createdAt
        case updatedAt
        case stickers
        case todoItems
    }

    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        richContentData: Data? = nil,
        category: MemoCategory,
        isPinned: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        stickers: [MemoSticker] = [],
        todoItems: [MemoTodoItem] = []
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.richContentData = richContentData
        self.category = category
        self.isPinned = isPinned
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.stickers = stickers
        self.todoItems = todoItems
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        richContentData = try container.decodeIfPresent(Data.self, forKey: .richContentData)
        category = try container.decode(MemoCategory.self, forKey: .category)
        isPinned = try container.decode(Bool.self, forKey: .isPinned)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        stickers = try container.decodeIfPresent([MemoSticker].self, forKey: .stickers) ?? []
        todoItems = try container.decodeIfPresent([MemoTodoItem].self, forKey: .todoItems) ?? []
    }
}

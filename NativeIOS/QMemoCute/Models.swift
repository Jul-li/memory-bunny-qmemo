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

struct Memo: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var content: String
    var category: MemoCategory
    var isPinned: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        category: MemoCategory,
        isPinned: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.category = category
        self.isPinned = isPinned
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

import Foundation

@MainActor
final class MemoStore: ObservableObject {
    @Published private(set) var memos: [Memo] = [] {
        didSet { save() }
    }

    private let storageKey = "qmemo.native.memos"

    init() {
        load()
    }

    @discardableResult
    func create(
        title: String,
        content: String,
        richContentData: Data? = nil,
        category: MemoCategory,
        isPinned: Bool,
        stickers: [MemoSticker] = [],
        todoItems: [MemoTodoItem] = []
    ) -> Memo {
        let memo = Memo(
            title: title,
            content: content,
            richContentData: richContentData,
            category: category,
            isPinned: isPinned,
            stickers: stickers,
            todoItems: todoItems
        )
        memos.append(memo)
        sortMemos()
        return memo
    }

    func update(
        _ memo: Memo,
        title: String,
        content: String,
        richContentData: Data? = nil,
        isPinned: Bool,
        stickers: [MemoSticker]? = nil,
        todoItems: [MemoTodoItem]? = nil
    ) {
        guard let index = memos.firstIndex(where: { $0.id == memo.id }) else { return }
        memos[index].title = title
        memos[index].content = content
        memos[index].richContentData = richContentData
        memos[index].isPinned = isPinned
        if let stickers {
            memos[index].stickers = stickers
        }
        if let todoItems {
            memos[index].todoItems = todoItems
        }
        memos[index].updatedAt = Date()
        sortMemos()
    }

    func delete(_ memo: Memo) {
        if memo.category == .todo {
            Task {
                await TodoReminderManager.shared.cancelReminders(
                    memoID: memo.id,
                    items: memo.todoItems
                )
            }
        }
        memos.removeAll { $0.id == memo.id }
    }

    func togglePin(_ memo: Memo) {
        guard let index = memos.firstIndex(where: { $0.id == memo.id }) else { return }
        memos[index].isPinned.toggle()
        memos[index].updatedAt = Date()
        sortMemos()
    }

    private func sortMemos() {
        memos.sort {
            if $0.isPinned != $1.isPinned {
                return $0.isPinned && !$1.isPinned
            }
            return $0.updatedAt > $1.updatedAt
        }
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder.qmemo.decode([Memo].self, from: data)
        else {
            memos = Self.seedMemos
            return
        }

        memos = decoded
        sortMemos()
    }

    private func save() {
        guard let data = try? JSONEncoder.qmemo.encode(memos) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private static let seedMemos: [Memo] = [
        Memo(title: "周末手账素材", content: "买粉色胶带、云朵贴纸和一支顺滑的奶油笔。", category: .life),
        Memo(title: "便利店新品灵感", content: "草莓牛乳包装可以做成小贴纸，配一个圆脸小杯子。", category: .idea),
        Memo(title: "英语听力计划", content: "每天 20 分钟精听，记录 5 个新表达，睡前复盘。", category: .study),
        Memo(title: "今天的小任务", content: "整理书桌、洗花、把课程截图归档到相册。", category: .todo)
    ]
}

private extension JSONEncoder {
    static var qmemo: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var qmemo: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

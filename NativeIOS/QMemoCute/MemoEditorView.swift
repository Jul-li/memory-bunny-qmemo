import SwiftUI

struct MemoEditorView: View {
    @EnvironmentObject private var store: MemoStore
    @Environment(\.dismiss) private var dismiss

    let category: MemoCategory
    let memo: Memo?

    @State private var title: String
    @State private var content: String
    @State private var isPinned: Bool

    init(category: MemoCategory, memo: Memo?) {
        self.category = category
        self.memo = memo
        _title = State(initialValue: memo?.title ?? "")
        _content = State(initialValue: memo?.content ?? "")
        _isPinned = State(initialValue: memo?.isPinned ?? false)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background
                    .ignoresSafeArea()

                VStack(spacing: 18) {
                    HStack(spacing: 10) {
                        Image(category.iconAsset)
                            .resizable()
                            .frame(width: 30, height: 30)
                        Text(category.title)
                            .font(.system(size: 18, weight: .black))
                        Spacer()
                        Toggle("置顶", isOn: $isPinned)
                            .font(.system(size: 15, weight: .bold))
                    }
                    .padding(.horizontal, 18)
                    .frame(height: 58)
                    .background(.white.opacity(0.86))
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                    VStack(spacing: 12) {
                        TextField("给这条便签起个名字", text: $title)
                            .font(.system(size: 24, weight: .black))
                            .textInputAutocapitalization(.never)

                        Divider()

                        TextEditor(text: $content)
                            .font(.system(size: 17, weight: .semibold))
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 260)
                    }
                    .padding(20)
                    .background(Theme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Theme.Colors.line, lineWidth: 1)
                    )

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle(memo == nil ? "新建便签" : "编辑便签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanContent = content.trimmingCharacters(in: .whitespacesAndNewlines)

        if let memo {
            store.update(memo, title: cleanTitle, content: cleanContent, isPinned: isPinned)
        } else {
            store.create(title: cleanTitle, content: cleanContent, category: category, isPinned: isPinned)
        }

        dismiss()
    }
}

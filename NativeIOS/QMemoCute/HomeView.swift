import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: MemoStore
    @State private var searchText = ""
    @State private var selectedCategory: MemoCategory?
    @State private var editorRoute: EditorRoute?
    @State private var isCreateMenuPresented = false

    private var filteredMemos: [Memo] {
        store.memos.filter { memo in
            let categoryMatches = selectedCategory == nil || memo.category == selectedCategory
            let textMatches = searchText.isEmpty
                || memo.title.localizedCaseInsensitiveContains(searchText)
                || memo.content.localizedCaseInsensitiveContains(searchText)
            return categoryMatches && textMatches
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Theme.Colors.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                    categoryScroller
                    sectionHeader
                    memoList
                }
                .padding(.top, 10)

                Button {
                    isCreateMenuPresented = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(.white)
                        .frame(width: 74, height: 74)
                        .background(Theme.Colors.accent)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.white, lineWidth: 5))
                        .shadow(color: Theme.Colors.accent.opacity(0.35), radius: 14, y: 8)
                }
                .padding(.trailing, 24)
                .padding(.bottom, 28)
            }
            .confirmationDialog("选择便签分类", isPresented: $isCreateMenuPresented) {
                ForEach(MemoCategory.allCases) { category in
                    Button(category.title) {
                        editorRoute = EditorRoute(category: category, memo: nil)
                    }
                }
            }
            .sheet(item: $editorRoute) { route in
                MemoEditorView(category: route.category, memo: route.memo)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                Image("Avatar")
                    .resizable()
                    .frame(width: 64, height: 64)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("记忆兔")
                        .font(.system(size: 36, weight: .black))
                        .foregroundStyle(Theme.Colors.text)
                    Text("今天想记点什么？")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.Colors.text.opacity(0.9))
                }

                Spacer()
            }

            HStack(spacing: 12) {
                Image("SearchIcon")
                    .resizable()
                    .frame(width: 26, height: 26)
                TextField("搜索灵感、待办或小心情", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .font(.system(size: 17, weight: .semibold))
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image("CloseIcon")
                            .resizable()
                            .frame(width: 22, height: 22)
                    }
                }
            }
            .padding(.horizontal, 18)
            .frame(height: 60)
            .background(.white)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Theme.Colors.line, lineWidth: 1))
        }
        .padding(.horizontal, 20)
    }

    private var categoryScroller: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                CategoryPill(title: "全部", icon: "CategoryAll", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }

                ForEach(MemoCategory.allCases) { category in
                    CategoryPill(title: category.title, icon: category.iconAsset, isSelected: selectedCategory == category) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }

    private var sectionHeader: some View {
        HStack {
            Text("我的便签")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(Theme.Colors.text)
            Spacer()
            Text("\(filteredMemos.count) 条")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.Colors.muted)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }

    private var memoList: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                ForEach(filteredMemos) { memo in
                    MemoCardView(memo: memo) {
                        editorRoute = EditorRoute(category: memo.category, memo: memo)
                    }
                    .contextMenu {
                        Button(memo.isPinned ? "取消置顶" : "置顶") {
                            store.togglePin(memo)
                        }
                        Button("编辑") {
                            editorRoute = EditorRoute(category: memo.category, memo: memo)
                        }
                        Button("删除", role: .destructive) {
                            store.delete(memo)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 120)
        }
    }
}

struct EditorRoute: Identifiable {
    let id = UUID()
    let category: MemoCategory
    let memo: Memo?
}

struct CategoryPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(icon)
                    .resizable()
                    .frame(width: 24, height: 24)
                Text(title)
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(Theme.Colors.text)
            }
            .padding(.horizontal, 18)
            .frame(height: 52)
            .background(isSelected ? Theme.Colors.cream : .white)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white, lineWidth: isSelected ? 2 : 0))
            .shadow(color: .black.opacity(isSelected ? 0.08 : 0.04), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
    }
}

struct MemoCardView: View {
    let memo: Memo
    let action: () -> Void

    private var dateText: String {
        memo.updatedAt.formatted(.dateTime.month().day().hour().minute())
    }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .trailing) {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(memo.category.tint)
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(.white, lineWidth: 3)
                    )

                Image(memo.category.stickerAsset)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .padding(.trailing, 28)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(memo.isPinned ? "CategoryPinned" : memo.category.iconAsset)
                            .resizable()
                            .frame(width: memo.isPinned ? 32 : 24, height: memo.isPinned ? 32 : 24)
                        Text(memo.category.title)
                            .font(.system(size: 16, weight: .black))
                    }
                    .foregroundStyle(Theme.Colors.text)
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(.white.opacity(0.72))
                    .clipShape(Capsule())

                    Text(memo.title)
                        .font(.system(size: 25, weight: .black))
                        .foregroundStyle(Theme.Colors.text)
                        .lineLimit(1)

                    Text(memo.content)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.Colors.text.opacity(0.75))
                        .lineLimit(2)
                        .frame(maxWidth: 250, alignment: .leading)

                    Text(dateText)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.Colors.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(22)
            }
            .frame(minHeight: 210)
        }
        .buttonStyle(.plain)
    }
}

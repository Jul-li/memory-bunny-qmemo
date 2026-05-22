import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: MemoStore
    @State private var searchText = ""
    @State private var isSearchPresented = false
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
            ZStack {
                Theme.Colors.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                    categoryScroller
                    sectionHeader
                    memoList
                }
                .padding(.top, 10)

                if isSearchPresented || isCreateMenuPresented {
                    Button {
                        closeOverlays()
                    } label: {
                        Rectangle()
                            .fill(Theme.Colors.cream.opacity(0.42))
                            .background(.ultraThinMaterial.opacity(0.72))
                            .ignoresSafeArea()
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                    .zIndex(2)
                }

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        createEntry
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 120)
                }
            }
            .sheet(item: $editorRoute) { route in
                MemoEditorView(category: route.category, memo: route.memo)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
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
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Theme.Colors.text.opacity(0.9))
                }

                Spacer()

                Button {
                    withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.34)) {
                        isCreateMenuPresented = false
                        if isSearchPresented {
                            searchText = ""
                        }
                        isSearchPresented.toggle()
                    }
                } label: {
                    Image(isSearchPresented ? "CloseIcon" : "SearchIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .frame(width: 54, height: 54)
                        .background(.white)
                        .clipShape(Circle())
                        .shadow(color: Theme.Colors.shadow.opacity(0.10), radius: 12, y: 5)
                }
                .buttonStyle(.plain)
            }

            if isSearchPresented {
                searchBox
                    .transition(.scale(scale: 0.88, anchor: .topTrailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 20)
        .zIndex(5)
    }

    private var searchBox: some View {
        HStack(spacing: 12) {
            Image("SearchIcon")
                .resizable()
                .frame(width: 26, height: 26)
            TextField("搜索灵感、待办或小心情", text: $searchText)
                .textInputAutocapitalization(.never)
                .font(.system(size: 17, weight: .semibold))
                .submitLabel(.search)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image("CloseIcon")
                        .resizable()
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 60)
        .background(.white)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Theme.Colors.line, lineWidth: 1))
        .shadow(color: Theme.Colors.shadow.opacity(0.10), radius: 16, y: 7)
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
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Theme.Colors.text)
            Spacer()
            Text("\(filteredMemos.count) 条")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.Colors.muted)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private var memoList: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                ForEach(filteredMemos) { memo in
                    MemoCardView(memo: memo) {
                        editorRoute = EditorRoute(category: memo.category, memo: memo)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 168)
        }
    }

    private var createEntry: some View {
        ZStack(alignment: .bottomTrailing) {
            if isCreateMenuPresented {
                CreateMenuView { category in
                    withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.22)) {
                        isCreateMenuPresented = false
                    }
                    editorRoute = EditorRoute(category: category, memo: nil)
                }
                .transition(.scale(scale: 0.22, anchor: .bottomTrailing).combined(with: .opacity))
            } else {
                Button {
                    withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.34)) {
                        isSearchPresented = false
                        isCreateMenuPresented = true
                    }
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
                .buttonStyle(.plain)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
        .zIndex(6)
    }

    private func closeOverlays() {
        withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.28)) {
            isCreateMenuPresented = false
            isSearchPresented = false
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
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Theme.Colors.text)
            }
            .padding(.horizontal, 18)
            .frame(height: 52)
            .background(isSelected ? Theme.Colors.cream : .white)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white, lineWidth: isSelected ? 2 : 0))
            .shadow(color: Theme.Colors.shadow.opacity(isSelected ? 0.12 : 0.07), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
    }
}

struct MemoCardView: View {
    @EnvironmentObject private var store: MemoStore
    let memo: Memo
    let action: () -> Void

    private var dateText: String {
        memo.updatedAt.formatted(.dateTime.month().day().hour().minute())
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: action) {
                ZStack(alignment: .trailing) {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .fill(Theme.Colors.memoCard)
                        .overlay(GridPaperPattern().clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous)))
                        .overlay(
                            RoundedRectangle(cornerRadius: 34, style: .continuous)
                                .stroke(.white, lineWidth: 3)
                        )
                        .shadow(color: Theme.Colors.shadow.opacity(0.12), radius: 16, y: 8)

                    Image(memo.category.stickerAsset)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 86, height: 86)
                        .padding(.trailing, 26)
                        .padding(.top, 38)

                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 8) {
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(memo.category.tint.opacity(0.55))
                                    .overlay(Capsule().stroke(.white, lineWidth: 1))

                                Image(memo.isPinned ? "CategoryPinned" : memo.category.iconAsset)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: memo.isPinned ? 32 : 24, height: memo.isPinned ? 32 : 24)
                                    .padding(.leading, memo.isPinned ? 2 : 10)
                            }
                            .frame(width: 46, height: 34)

                            Text(memo.category.title)
                                .font(.system(size: 15, weight: .black))
                                .foregroundStyle(Theme.Colors.text)
                        }
                        .padding(.bottom, 14)

                        HStack(alignment: .center, spacing: 8) {
                            if memo.isPinned {
                                Image(memo.category.iconAsset)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 32, height: 32)
                            }

                            Text(memo.title)
                                .font(.system(size: 20, weight: .black))
                                .foregroundStyle(Theme.Colors.text)
                                .lineLimit(1)
                                .frame(maxWidth: 218, alignment: .leading)
                        }

                        Text(memo.content)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(Theme.Colors.text.opacity(0.78))
                            .lineLimit(2)
                            .lineSpacing(4)
                            .frame(maxWidth: 230, alignment: .leading)
                            .padding(.top, 4)

                        Text(dateText)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.Colors.muted)
                            .padding(.top, 6)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(22)
                }
                .frame(minHeight: 190)
            }
            .buttonStyle(.plain)

            Menu {
                Button(memo.isPinned ? "取消置顶" : "置顶") {
                    store.togglePin(memo)
                }
                Button("编辑") {
                    action()
                }
                Button("删除", role: .destructive) {
                    store.delete(memo)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.Colors.muted)
                    .frame(width: 42, height: 42)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.top, 18)
            .padding(.trailing, 18)
        }
        .contextMenu {
            Button(memo.isPinned ? "取消置顶" : "置顶") {
                store.togglePin(memo)
            }
            Button("编辑") {
                action()
            }
            Button("删除", role: .destructive) {
                store.delete(memo)
            }
        }
    }
}

struct GridPaperPattern: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 18
            var path = Path()
            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }

            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }

            context.stroke(path, with: .color(.black.opacity(0.02)), lineWidth: 1)
        }
    }
}

struct CreateMenuView: View {
    let onSelect: (MemoCategory) -> Void

    var body: some View {
        VStack(spacing: 12) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 6) {
                    ForEach(MemoCategory.allCases) { category in
                        Button {
                            onSelect(category)
                        } label: {
                            HStack(spacing: 12) {
                                Image(category.iconAsset)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 44, height: 44)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(category.title)
                                        .font(.system(size: 17, weight: .black))
                                        .foregroundStyle(Theme.Colors.text)
                                    Text(category.createDescription)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Theme.Colors.muted)
                                        .lineLimit(1)
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 62)
                            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(CreateMenuRowStyle())
                    }
                }
            }
            .frame(maxHeight: 330)

            Image(systemName: "plus")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.white)
                .frame(width: 62, height: 62)
                .background(Theme.Colors.accent)
                .clipShape(Circle())
                .overlay(Circle().stroke(.white, lineWidth: 4))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(12)
        .frame(width: 286)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(Theme.Colors.line, lineWidth: 1)
        )
        .shadow(color: Theme.Colors.shadow.opacity(0.18), radius: 22, y: 10)
    }
}

struct CreateMenuRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.black.opacity(0.05) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private extension MemoCategory {
    var createDescription: String {
        switch self {
        case .life: "记录日常小事和灵感"
        case .todo: "安排今天要完成的事"
        case .study: "整理学习笔记和计划"
        case .idea: "收集突然冒出的想法"
        case .diary: "写下此刻的小心情"
        }
    }
}

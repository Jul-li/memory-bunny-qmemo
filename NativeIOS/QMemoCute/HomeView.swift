import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: MemoStore
    @State private var searchText = ""
    @State private var isSearchPresented = false
    @State private var searchIconName = "SearchIcon"
    @State private var searchIconScale = 1.0
    @State private var searchBoxDropped = false
    @State private var searchBoxExpanded = false
    @State private var searchBoxChromeVisible = false
    @State private var selectedCategory: MemoCategory?
    @State private var editorRoute: EditorRoute?
    @State private var isCreateMenuPresented = false
    @State private var isCreateMenuContentVisible = false

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
                    Spacer()
                }
                .padding(.top, 10)
                .zIndex(8)

                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: 64)
                    categoryScroller
                    sectionHeader
                    memoList
                }
                .padding(.top, 10)
                .blur(radius: isSearchPresented ? 16 : 0)
                .animation(.easeOut(duration: 0.24), value: isSearchPresented)
                .zIndex(0)

                if isSearchPresented || isCreateMenuPresented {
                    Button {
                        closeOverlays()
                    } label: {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .opacity(0.58)
                            .overlay(Theme.Colors.cream.opacity(0.22))
                            .ignoresSafeArea()
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                    .zIndex(2)
                }

                if isSearchPresented && !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    searchResultsLayer
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .zIndex(5)
                }

                if isSearchPresented {
                    VStack {
                        HStack {
                            Spacer()
                            searchBox
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 74)
                        Spacer()
                    }
                    .transition(.opacity)
                    .zIndex(7)
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
                .blur(radius: isSearchPresented ? 16 : 0)
                .animation(.easeOut(duration: 0.24), value: isSearchPresented)
                .zIndex(isCreateMenuPresented ? 6 : 1)
            }
            .sheet(item: $editorRoute) { route in
                MemoEditorView(category: route.category, memo: route.memo)
            }
        }
    }

    private var header: some View {
        ZStack(alignment: .trailing) {
            HStack(alignment: .center, spacing: 14) {
                Image("Avatar")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 4) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 126, height: 48, alignment: .leading)
                    Text("今天想记点什么？")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Theme.Colors.text.opacity(0.9))
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 68)

            Button {
                toggleSearch()
            } label: {
                Image(searchIconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 42, height: 42)
                    .frame(width: 54, height: 54)
                    .scaleEffect(searchIconScale)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 64)
        .padding(.horizontal, 20)
        .zIndex(8)
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
        .opacity(searchBoxExpanded ? 1 : 0)
        .frame(width: searchBoxExpanded ? UIScreen.main.bounds.width - 40 : 54, height: searchBoxDropped ? 60 : 54)
        .background(.white.opacity(searchBoxChromeVisible ? 1 : 0))
        .mask(RoundedRectangle(cornerRadius: searchBoxExpanded ? 30 : 27, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: searchBoxExpanded ? 30 : 27, style: .continuous)
                .stroke(Theme.Colors.line.opacity(searchBoxChromeVisible ? 1 : 0), lineWidth: 1)
        )
        .shadow(color: Theme.Colors.shadow.opacity(searchBoxChromeVisible ? 0.14 : 0), radius: 18, y: 8)
        .offset(y: searchBoxDropped ? 12 : -44)
        .animation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.30), value: searchBoxDropped)
        .animation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.34), value: searchBoxExpanded)
        .animation(.easeOut(duration: 0.12), value: searchBoxChromeVisible)
    }

    private var searchResultsLayer: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: 158)

            HStack {
                Text("搜索结果")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Theme.Colors.text)
                Spacer()
                Text("\(filteredMemos.count) 条")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.Colors.muted)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            if filteredMemos.isEmpty {
                VStack(spacing: 8) {
                    Text("没有找到相关便签")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.Colors.text)
                    Text("换个关键词试试")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Theme.Colors.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 58)

                Spacer(minLength: 0)
            } else {
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var categoryScroller: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
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
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .frame(height: 74)
        .padding(.top, 8)
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
            ZStack {
                RoundedRectangle(cornerRadius: isCreateMenuPresented ? 30 : 37, style: .continuous)
                    .fill(Theme.Colors.accent)
                    .opacity(isCreateMenuPresented ? 0 : 1)

                RoundedRectangle(cornerRadius: isCreateMenuPresented ? 30 : 37, style: .continuous)
                    .fill(.regularMaterial)
                    .opacity(isCreateMenuPresented ? 1 : 0)
            }
            .overlay(
                RoundedRectangle(cornerRadius: isCreateMenuPresented ? 30 : 37, style: .continuous)
                    .stroke(isCreateMenuPresented ? .white.opacity(0.62) : .white, lineWidth: isCreateMenuPresented ? 1 : 5)
            )
            .shadow(
                color: (isCreateMenuPresented ? Color.black : Theme.Colors.accent).opacity(isCreateMenuPresented ? 0.16 : 0.35),
                radius: isCreateMenuPresented ? 28 : 14,
                y: isCreateMenuPresented ? 14 : 8
            )
            .overlay(
                RoundedRectangle(cornerRadius: isCreateMenuPresented ? 30 : 37, style: .continuous)
                    .stroke(Theme.Colors.line.opacity(isCreateMenuPresented ? 0.28 : 0), lineWidth: 1)
                    .padding(0.5)
            )

            if !isCreateMenuPresented {
                Image("CreateEntryIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .offset(x: -5, y: -14)
                    .transition(.scale(scale: 0.86).combined(with: .opacity))
                    .allowsHitTesting(false)
            }

            if isCreateMenuPresented {
                CreateMenuContentView { category in
                    closeCreateMenu()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
                        editorRoute = EditorRoute(category: category, memo: nil)
                    }
                }
                .padding(12)
                .frame(width: 286, height: 404, alignment: .topLeading)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .opacity(isCreateMenuContentVisible ? 1 : 0)
                .offset(y: isCreateMenuContentVisible ? 0 : 10)
                .animation(.easeOut(duration: 0.18), value: isCreateMenuContentVisible)
            }

            if !isCreateMenuPresented {
                Button {
                    openCreateMenu()
                } label: {
                    Color.clear
                        .frame(width: 74, height: 74)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: isCreateMenuPresented ? 286 : 74, height: isCreateMenuPresented ? 404 : 74)
        .offset(y: isCreateMenuPresented ? -16 : 0)
        .scaleEffect(isCreateMenuPresented ? 1 : 1, anchor: .bottomTrailing)
        .animation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.42), value: isCreateMenuPresented)
    }

    private func closeOverlays() {
        let shouldResetSearchIcon = isSearchPresented || searchIconName != "SearchIcon"
        if isSearchPresented {
            closeSearch()
        }
        if isCreateMenuPresented {
            closeCreateMenu()
        }
        if shouldResetSearchIcon {
            searchText = ""
        }
    }

    private func toggleSearch() {
        if isSearchPresented {
            closeSearch()
        } else {
            openSearch()
        }
    }

    private func openSearch() {
        searchBoxDropped = false
        searchBoxExpanded = false
        searchBoxChromeVisible = true
        isCreateMenuContentVisible = false
        isCreateMenuPresented = false
        withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.30)) {
            isSearchPresented = true
        }
        animateSearchIcon(to: "CloseIcon")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.30)) {
                searchBoxDropped = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.34)) {
                searchBoxExpanded = true
            }
        }
    }

    private func openCreateMenu() {
        withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.34)) {
            isSearchPresented = false
            searchIconName = "SearchIcon"
            searchIconScale = 1
            isCreateMenuContentVisible = false
            isCreateMenuPresented = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            if isCreateMenuPresented {
                withAnimation(.easeOut(duration: 0.18)) {
                    isCreateMenuContentVisible = true
                }
            }
        }
    }

    private func closeCreateMenu() {
        withAnimation(.easeOut(duration: 0.10)) {
            isCreateMenuContentVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.28)) {
                isCreateMenuPresented = false
            }
        }
    }

    private func closeSearch() {
        withAnimation(.timingCurve(0.64, 0, 0.78, 0, duration: 0.22)) {
            searchBoxExpanded = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            searchBoxChromeVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            withAnimation(.timingCurve(0.64, 0, 0.78, 0, duration: 0.22)) {
                searchBoxDropped = false
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            withAnimation(.timingCurve(0.64, 0, 0.78, 0, duration: 0.18)) {
                isSearchPresented = false
                searchText = ""
            }
            searchBoxChromeVisible = false
        }
        animateSearchIcon(to: "SearchIcon")
    }

    private func animateSearchIcon(to name: String) {
        withAnimation(.easeOut(duration: 0.15)) {
            searchIconScale = 0.01
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            searchIconName = name
            searchIconScale = 0.01
            withAnimation(.interpolatingSpring(stiffness: 170, damping: 12)) {
                searchIconScale = 1
            }
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
    @State private var isSwitchAnimating = false

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.08)) {
                isSwitchAnimating = true
            }
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.interpolatingSpring(stiffness: 220, damping: 16)) {
                    isSwitchAnimating = false
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(icon)
                    .resizable()
                    .frame(width: 24, height: 24)
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isSelected ? Theme.Colors.text : Theme.Colors.muted)
            }
            .padding(.horizontal, 15)
            .frame(height: 40)
            .background(isSelected ? Theme.Colors.cream : .white)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white, lineWidth: isSelected ? 2 : 0))
            .shadow(color: Theme.Colors.shadow.opacity(isSelected ? 0.12 : 0.07), radius: 10, y: 5)
        }
        .scaleEffect(isSwitchAnimating ? 0.95 : 1)
        .buttonStyle(CategoryPillPressStyle())
    }
}

struct CategoryPillPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
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
                            MemoCategoryBadge(memo: memo)
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
                Button {
                    store.togglePin(memo)
                } label: {
                    MemoActionMenuLabel(
                        title: memo.isPinned ? "取消置顶" : "置顶",
                        icon: memo.isPinned ? "ActionUnpin" : "ActionPin"
                    )
                }
                Button {
                    action()
                } label: {
                    MemoActionMenuLabel(title: "编辑", icon: "ActionEdit")
                }
                Button(role: .destructive) {
                    store.delete(memo)
                } label: {
                    MemoActionMenuLabel(title: "删除", icon: "ActionDelete")
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
            Button {
                store.togglePin(memo)
            } label: {
                MemoActionMenuLabel(
                    title: memo.isPinned ? "取消置顶" : "置顶",
                    icon: memo.isPinned ? "ActionUnpin" : "ActionPin"
                )
            }
            Button {
                action()
            } label: {
                MemoActionMenuLabel(title: "编辑", icon: "ActionEdit")
            }
            Button(role: .destructive) {
                store.delete(memo)
            } label: {
                MemoActionMenuLabel(title: "删除", icon: "ActionDelete")
            }
        }
    }
}

struct MemoCategoryBadge: View {
    let memo: Memo

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            HStack(spacing: 6) {
                if !memo.isPinned {
                    Image(memo.category.iconAsset)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                }

                Text(memo.isPinned ? "置顶" : memo.category.title)
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Theme.Colors.text)
            }
            .padding(.leading, memo.isPinned ? 42 : 10)
            .padding(.trailing, 10)
            .frame(height: 36)
            .background(memo.category.tint.opacity(0.55))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white, lineWidth: 1))

            if memo.isPinned {
                Image("CategoryPinned")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .padding(.leading, 4)
                    .padding(.bottom, 6)
            }
        }
        .frame(height: 36, alignment: .bottomLeading)
    }
}

struct MemoActionMenuLabel: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 10) {
            Image(icon)
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)

            Text(title)

            Spacer(minLength: 0)
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

struct CreateMenuContentView: View {
    let onSelect: (MemoCategory) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("新建便签")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Theme.Colors.text)
                .padding(.horizontal, 12)

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
        }
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

import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case categories
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "备忘"
        case .categories: "分类"
        case .settings: "设置"
        }
    }

    var icon: String {
        switch self {
        case .home: "TabHome"
        case .categories: "TabCategories"
        case .settings: "TabSettings"
        }
    }
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .home

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .home:
                    HomeView()
                case .categories:
                    CategorySummaryView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            CuteNativeTabBar(selectedTab: $selectedTab)
                .padding(.horizontal, 12)
                .padding(.bottom, 18)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

struct CuteNativeTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.34)) {
                        selectedTab = tab
                    }
                } label: {
                    CuteNativeTabItem(tab: tab, isSelected: selectedTab == tab)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 78)
        .background(.white)
        .clipShape(Capsule())
        .shadow(color: Theme.Colors.shadow.opacity(0.12), radius: 18, y: 6)
    }
}

struct CuteNativeTabItem: View {
    let tab: AppTab
    let isSelected: Bool

    var body: some View {
        HStack(spacing: isSelected ? 4 : 0) {
            Image(tab.icon)
                .resizable()
                .scaledToFit()
                .frame(width: isSelected ? 46 : 34, height: isSelected ? 46 : 34)
                .offset(x: isSelected ? -4 : 0)

            if isSelected {
                Text(tab.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.Colors.accentStrong)
                    .lineLimit(1)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
        .padding(.horizontal, isSelected ? 14 : 0)
        .frame(width: isSelected ? 126 : 64, height: 52)
        .background(isSelected ? Color(hex: "FFE5EA") : .clear)
        .clipShape(Capsule())
        .overlay {
            if isSelected {
                Capsule()
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Color(hex: "FDFDFB"))
                    .padding(3)
            }
        }
        .overlay(
            Capsule()
                .stroke(isSelected ? Color(hex: "F7C6CD") : .clear, lineWidth: 1)
        )
    }
}

struct CategorySummaryView: View {
    @EnvironmentObject private var store: MemoStore

    var body: some View {
        NavigationStack {
            List {
                ForEach(MemoCategory.allCases) { category in
                    HStack(spacing: 12) {
                        Image(category.iconAsset)
                            .resizable()
                            .frame(width: 30, height: 30)
                        Text(category.title)
                            .font(.headline)
                        Spacer()
                        Text("\(store.memos.filter { $0.category == category }.count)")
                            .foregroundStyle(Theme.Colors.muted)
                    }
                    .listRowBackground(Theme.Colors.surface)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.background)
            .navigationTitle("分类")
        }
        .padding(.bottom, 96)
    }
}

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("应用") {
                    Label("本地备忘录", systemImage: "iphone")
                    Label("无登录，无后端", systemImage: "lock.shield")
                    Label("原生 SwiftUI 版本", systemImage: "swift")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.background)
            .navigationTitle("设置")
        }
        .padding(.bottom, 96)
    }
}

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Image(systemName: "note.text")
                    Text("备忘")
                }

            CategorySummaryView()
                .tabItem {
                    Image(systemName: "square.grid.2x2")
                    Text("分类")
                }

            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("设置")
                }
        }
        .tint(Theme.Colors.accentStrong)
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
    }
}

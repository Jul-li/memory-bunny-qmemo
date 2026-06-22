import SwiftUI

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

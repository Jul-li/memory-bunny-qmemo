import SwiftUI

@main
struct QMemoCuteApp: App {
    @StateObject private var memoStore = MemoStore()

    init() {
        TodoReminderManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(memoStore)
        }
    }
}

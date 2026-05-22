import SwiftUI

@main
struct QMemoCuteApp: App {
    @StateObject private var memoStore = MemoStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(memoStore)
        }
    }
}

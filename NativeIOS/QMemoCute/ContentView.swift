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
    @State private var isTabBarHidden = false
    @State private var isHomeOverlayPresented = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.Colors.background
                .ignoresSafeArea()

            Group {
                switch selectedTab {
                case .home:
                    HomeView(
                        isTabBarHidden: $isTabBarHidden,
                        isHomeOverlayPresented: $isHomeOverlayPresented
                    )
                case .categories:
                    CategorySummaryView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !isTabBarHidden {
                ZStack(alignment: .bottom) {
                    bottomTabBarChrome

                    CuteNativeTabBar(selectedTab: $selectedTab)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                }
                .blur(radius: isHomeOverlayPresented ? 16 : 0)
                .opacity(isHomeOverlayPresented ? 0.24 : 1)
                .allowsHitTesting(!isHomeOverlayPresented)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeOut(duration: 0.24), value: isHomeOverlayPresented)
                .zIndex(2)
            }
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .windowBackground(UIColor(Theme.Colors.background))
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .animation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.28), value: isTabBarHidden)
        .onChange(of: selectedTab) { _, tab in
            if tab != .home {
                isTabBarHidden = false
                isHomeOverlayPresented = false
            }
        }
    }

    private var bottomTabBarChrome: some View {
        VStack {
            Spacer()
            qMemoChromeMaterial(
                tintOpacity: 0.16,
                mask: LinearGradient(
                    colors: [.clear, .clear, .black.opacity(0.62), .black],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .allowsHitTesting(false)
            .overlay(
                LinearGradient(
                    colors: [
                        Theme.Colors.background.opacity(0),
                        Theme.Colors.background.opacity(0),
                        Theme.Colors.background.opacity(0.62),
                        Theme.Colors.background.opacity(0.78),
                        Theme.Colors.background.opacity(1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(height: 142)
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)
        }
        .allowsHitTesting(false)
    }
}

private struct WindowBackgroundSetter: UIViewRepresentable {
    let color: UIColor

    func makeUIView(context: Context) -> BackgroundResolverView {
        let view = BackgroundResolverView()
        view.color = color
        DispatchQueue.main.async {
            applyBackground(from: view)
        }
        return view
    }

    func updateUIView(_ uiView: BackgroundResolverView, context: Context) {
        DispatchQueue.main.async {
            applyBackground(from: uiView)
        }
    }

    private func applyBackground(from view: BackgroundResolverView) {
        view.color = color
        view.applyBackground()
    }

    final class BackgroundResolverView: UIView {
        var color: UIColor = .clear

        override func didMoveToWindow() {
            super.didMoveToWindow()
            applyBackground()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            applyBackground()
        }

        func applyBackground() {
            window?.backgroundColor = color
            colorNavigationContainers(from: self)
        }

        private func colorNavigationContainers(from view: UIView) {
            var responder: UIResponder? = view
            while let current = responder {
                if let controller = current as? UIViewController {
                    controller.view.backgroundColor = color
                    controller.navigationController?.view.backgroundColor = color
                    controller.navigationController?.view.subviews.forEach { container in
                        if shouldColorContainer(container) {
                            container.backgroundColor = color
                        }
                    }
                }
                responder = current.next
            }
        }

        private func shouldColorContainer(_ view: UIView) -> Bool {
            let className = String(describing: type(of: view))
            return className.contains("Transition")
                || className.contains("UILayoutContainer")
                || className.contains("ControllerWrapper")
                || className.contains("DropShadow")
                || className.contains("Presentation")
                || className.contains("Dimming")
                || className.contains("Backdrop")
                || className.contains("Snapshot")
        }
    }
}

extension View {
    func windowBackground(_ color: UIColor) -> some View {
        background(WindowBackgroundSetter(color: color).frame(width: 0, height: 0))
    }

    func disablesNavigationDragDismiss() -> some View {
        background(NavigationDragDismissDisabler().frame(width: 0, height: 0))
    }
}

private struct NavigationDragDismissDisabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ uiViewController: Controller, context: Context) {
        DispatchQueue.main.async {
            uiViewController.disableNavigationGestures()
        }
    }

    final class Controller: UIViewController {
        private var originalStates: [ObjectIdentifier: (gesture: UIGestureRecognizer, isEnabled: Bool)] = [:]

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            disableNavigationGestures()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                self.disableNavigationGestures()
            }
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            disableNavigationGestures()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            disableNavigationGestures()
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            disableNavigationGestures()
        }

        deinit {
            restoreGestures()
        }

        func disableNavigationGestures() {
            guard let navigationController = navigationController ?? parent?.navigationController ?? nearestNavigationController() else { return }

            if let popGesture = navigationController.interactivePopGestureRecognizer {
                disable(popGesture)
            }

            disableDismissGestures(in: navigationController.view)
        }

        private func nearestNavigationController() -> UINavigationController? {
            var responder: UIResponder? = self
            while let current = responder {
                if let navigationController = current as? UINavigationController {
                    return navigationController
                }
                if let controller = current as? UIViewController, let navigationController = controller.navigationController {
                    return navigationController
                }
                responder = current.next
            }
            return view.window?.rootViewController.flatMap { findNavigationController(in: $0) }
        }

        private func findNavigationController(in controller: UIViewController) -> UINavigationController? {
            if let navigationController = controller as? UINavigationController {
                return navigationController
            }

            for child in controller.children {
                if let navigationController = findNavigationController(in: child) {
                    return navigationController
                }
            }

            return controller.presentedViewController.flatMap { findNavigationController(in: $0) }
        }

        private func disableDismissGestures(in view: UIView) {
            if view is UIControl || view is UIScrollView {
                return
            }

            view.gestureRecognizers?.forEach { gesture in
                if shouldDisable(gesture) {
                    disable(gesture)
                }
            }

            view.subviews.forEach { disableDismissGestures(in: $0) }
        }

        private func shouldDisable(_ gesture: UIGestureRecognizer) -> Bool {
            gesture is UIPanGestureRecognizer
                || gesture is UIScreenEdgePanGestureRecognizer
                || gesture is UILongPressGestureRecognizer
        }

        private func disable(_ gesture: UIGestureRecognizer) {
            let key = ObjectIdentifier(gesture)
            if originalStates[key] == nil {
                originalStates[key] = (gesture, gesture.isEnabled)
            }
            gesture.isEnabled = false
        }

        private func restoreGestures() {
            originalStates.values.forEach { entry in
                entry.gesture.isEnabled = entry.isEnabled
            }
            originalStates.removeAll()
        }
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

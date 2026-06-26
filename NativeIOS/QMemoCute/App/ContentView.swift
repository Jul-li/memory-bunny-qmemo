import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case categories
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "备忘"
        case .categories: "统计"
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
    @State private var statisticsEntryID = UUID()

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.Colors.background
                .ignoresSafeArea()

            Group {
                switch selectedTab {
                case .home:
                    HomeView(
                        selectedTab: $selectedTab,
                        isTabBarHidden: $isTabBarHidden,
                        isHomeOverlayPresented: $isHomeOverlayPresented
                    )
                case .categories:
                    StatisticsView(
                        isTabBarHidden: $isTabBarHidden,
                        entryID: statisticsEntryID
                    )
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !isTabBarHidden {
                ZStack(alignment: .bottom) {
                    bottomTabBarChrome

                    CuteNativeTabBar(selectedTab: $selectedTab) { previousTab, nextTab in
                        if previousTab != .categories && nextTab == .categories {
                            statisticsEntryID = UUID()
                        }
                    }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                }
                .allowsHitTesting(!isHomeOverlayPresented)
                .animation(.easeOut(duration: 0.24), value: isHomeOverlayPresented)
                .zIndex(2)
            }
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .windowBackground(UIColor(Theme.Colors.background))
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .animation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.28), value: isTabBarHidden)
        .onChange(of: selectedTab) {
            isTabBarHidden = false
            isHomeOverlayPresented = false
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
    let onSelectTab: (AppTab, AppTab) -> Void

    init(
        selectedTab: Binding<AppTab>,
        onSelectTab: @escaping (AppTab, AppTab) -> Void = { _, _ in }
    ) {
        _selectedTab = selectedTab
        self.onSelectTab = onSelectTab
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    let previousTab = selectedTab
                    onSelectTab(previousTab, tab)
                    withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.34)) {
                        selectedTab = tab
                    }
                } label: {
                    CuteNativeTabItem(tab: tab, isSelected: selectedTab == tab)
                }
                .buttonStyle(CuteTabBarButtonStyle())
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 78)
        .background(.white)
        .clipShape(Capsule())
        .shadow(color: Theme.Colors.shadow.opacity(0.12), radius: 18, y: 6)
        .animation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.34), value: selectedTab)
    }
}

private struct CuteTabBarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
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

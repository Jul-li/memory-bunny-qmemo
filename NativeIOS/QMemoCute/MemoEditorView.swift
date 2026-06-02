import SwiftUI
import UIKit

enum MemoEditorNavigationChrome {
    case native
    case cardExpanded
}

struct MemoEditorView: View {
    @EnvironmentObject private var store: MemoStore
    @Environment(\.dismiss) private var dismiss

    let category: MemoCategory
    let memo: Memo?
    let navigationChrome: MemoEditorNavigationChrome

    @State private var title: String
    @State private var content: String
    @State private var isPinned: Bool
    @State private var isCustomNavigationVisible = false
    @State private var bodyTextHeight: CGFloat = 520
    @State private var undoStack: [MemoEditorSnapshot]
    @State private var isApplyingUndo = false
    @State private var isUndoControlVisible = false
    @State private var isStickerPickerPresented = false
    @State private var isFormatPanelPresented = false
    @State private var isDeleteConfirmationPresented = false
    @State private var placedStickers: [PlacedEditorSticker] = []
    @State private var selectedStickerID: UUID?
    @State private var stickerDeletePromptID: UUID?
    @State private var shouldSkipPersistOnDisappear = false
    @State private var selectedBlockStyle: EditorBlockStyle = .body
    @State private var activeInlineStyles: Set<EditorInlineStyle> = []
    @State private var pendingFormatCommand: EditorFormatCommand?
    private let editorLineSpacing: CGFloat = 32
    private let editorBodyLineSpacing: CGFloat = 8
    private var canUndoInput: Bool {
        !undoStack.isEmpty
    }
    private var hasEditableDraftContent: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !placedStickers.isEmpty
    }
    private var shouldShowMoreButton: Bool {
        memo != nil || hasEditableDraftContent
    }
    private var editorTopPadding: CGFloat {
        navigationChrome == .cardExpanded ? 76 : 18
    }
    private var metadataText: String {
        "\(Self.metadataDateFormatter.string(from: memo?.updatedAt ?? Date()))｜\(bodyCharacterCount)字"
    }
    private var bodyCharacterCount: Int {
        content.filter { !$0.isWhitespace && !$0.isNewline }.count
    }
    private var editorBodyHeight: CGFloat {
        max(bodyTextHeight, 520)
    }
    private var stickerExclusionPaths: [UIBezierPath] {
        placedStickers.flatMap(\.textExclusionPaths)
    }
    private var stickerPickerColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 92), spacing: 12)
        ]
    }

    init(
        category: MemoCategory,
        memo: Memo?,
        navigationChrome: MemoEditorNavigationChrome = .native
    ) {
        self.category = category
        self.memo = memo
        self.navigationChrome = navigationChrome
        _title = State(initialValue: memo?.title ?? "")
        _content = State(initialValue: memo?.content ?? "")
        _isPinned = State(initialValue: memo?.isPinned ?? false)
        _undoStack = State(initialValue: [])
        _placedStickers = State(initialValue: memo?.stickers.map(PlacedEditorSticker.init) ?? [])
    }

    var body: some View {
        ZStack {
            Theme.Colors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    TextField("给这条便签起个名字", text: $title)
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(Theme.Colors.text)
                        .textInputAutocapitalization(.never)
                        .frame(maxWidth: .infinity, minHeight: editorLineSpacing, alignment: .leading)
                        .padding(.top, 0)

                    Text(metadataText)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.Colors.muted.opacity(0.72))
                        .padding(.top, 6)

                    editorBodyInput
                        .padding(.top, 20)
                        .frame(height: editorBodyHeight)
                        .overlay(alignment: .topLeading) {
                            editorStickerLayer
                        }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.horizontal, 20)
                .padding(.top, navigationChrome == .cardExpanded ? editorTopPadding : 0)
                .padding(.bottom, 176)
            }
            .scrollIndicators(.hidden)
            .padding(.top, navigationChrome == .cardExpanded ? 0 : editorTopPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            bottomFunctionOverlay
                .zIndex(2)

            if isStickerPickerPresented {
                stickerPickerOverlay
                    .zIndex(4)
                    .animation(.spring(response: 0.30, dampingFraction: 0.74), value: isStickerPickerPresented)
            }

            if isDeleteConfirmationPresented {
                DeleteConfirmationOverlay(
                    onCancel: {
                        withAnimation(.easeOut(duration: 0.18)) {
                            isDeleteConfirmationPresented = false
                        }
                    },
                    onConfirm: confirmDeleteOrDiscardDraft
                )
                .zIndex(10)
            }

            if navigationChrome == .cardExpanded {
                navigationGradient
                    .zIndex(2)
                customNavigationBar
                    .zIndex(3)
            }
        }
        .navigationTitle(memo == nil ? "新建便签" : "编辑便签")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isUndoControlVisible {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        undoLastInput()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .accessibilityLabel("撤回")
                }
            }

            if shouldShowMoreButton {
                ToolbarItem(placement: .confirmationAction) {
                    editorMoreMenu
                }
            }
        }
        .toolbar(navigationChrome == .cardExpanded ? .hidden : .visible, for: .navigationBar)
        .onAppear {
            guard navigationChrome == .cardExpanded else { return }

            isCustomNavigationVisible = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.24)) {
                    isCustomNavigationVisible = true
                }
            }
        }
        .onDisappear {
            persistDraftIfNeeded()
            isCustomNavigationVisible = false
        }
        .onChange(of: title) { oldValue, _ in
            recordUndoSnapshot(title: oldValue, content: content)
        }
        .onChange(of: content) { oldValue, _ in
            recordUndoSnapshot(title: title, content: oldValue)
        }
    }

    private var customNavigationBar: some View {
        VStack {
            HStack(spacing: 14) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.Colors.text)
                        .frame(width: 44, height: 44)
                        .background(
                            QMemoGlassBackground(
                                shape: Circle(),
                                tintOpacity: 0.20,
                                fallbackFillOpacity: 0.84,
                                strokeOpacity: 0.70,
                                lineOpacity: 0.10
                            )
                        )
                        .shadow(color: Theme.Colors.shadow.opacity(0.10), radius: 10, y: 4)
                }
                .buttonStyle(.plain)

                Spacer()

                if isUndoControlVisible {
                    Button {
                        undoLastInput()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Theme.Colors.text)
                            .frame(width: 44, height: 44)
                            .background(
                                QMemoGlassBackground(
                                    shape: Circle(),
                                    tintOpacity: 0.20,
                                    fallbackFillOpacity: 0.84,
                                    strokeOpacity: 0.70,
                                    lineOpacity: 0.10
                                )
                            )
                            .shadow(color: Theme.Colors.shadow.opacity(0.10), radius: 10, y: 4)
                    }
                    .accessibilityLabel("撤回")
                    .buttonStyle(.plain)
                    .transition(.scale(scale: 0.86).combined(with: .opacity))
                }

                if shouldShowMoreButton {
                    editorMoreMenu
                }
            }
            .animation(.spring(response: 0.24, dampingFraction: 0.86), value: isUndoControlVisible)
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 10)

            Spacer()
        }
        .opacity(isCustomNavigationVisible ? 1 : 0)
        .offset(y: isCustomNavigationVisible ? 0 : -34)
        .allowsHitTesting(isCustomNavigationVisible)
    }

    private var editorMoreMenu: some View {
        EditorMoreMenuButton(
            isPinned: isPinned,
            onTogglePin: {
                isPinned.toggle()
            },
            onDelete: {
                requestDeleteConfirmation()
            }
        )
        .frame(width: 44, height: 44)
    }

    private var navigationGradient: some View {
        VStack {
            ZStack {
                qMemoChromeMaterial(
                    tintOpacity: 0.16,
                    mask: LinearGradient(
                        colors: [.black, .black.opacity(0.72), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LinearGradient(
                    colors: [
                        Theme.Colors.background.opacity(1),
                        Theme.Colors.background.opacity(0.72),
                        Theme.Colors.background.opacity(0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(height: 150)
            .ignoresSafeArea(edges: .top)

            Spacer()
        }
        .allowsHitTesting(false)
    }

    private var bottomFunctionOverlay: some View {
        ZStack(alignment: .bottom) {
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
                .frame(height: 158)
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
            }

            VStack {
                Spacer()
                functionPanel
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }

            if isFormatPanelPresented {
                VStack {
                    Spacer()
                    formatPanel
                        .padding(.horizontal, 20)
                        .padding(.bottom, 82)
                }
                .transition(.formatPanelReveal)
                .animation(.spring(response: 0.30, dampingFraction: 0.74), value: isFormatPanelPresented)
            }
        }
    }

    private var editorBodyInput: some View {
        MemoBodyTextView(
            text: $content,
            calculatedHeight: $bodyTextHeight,
            selectedBlockStyle: $selectedBlockStyle,
            activeInlineStyles: $activeInlineStyles,
            pendingFormatCommand: $pendingFormatCommand,
            textColor: UIColor(Theme.Colors.text),
            lineSpacing: editorBodyLineSpacing,
            exclusionPaths: stickerExclusionPaths
        )
    }

    private var editorStickerLayer: some View {
        ZStack(alignment: .topLeading) {
            ForEach($placedStickers) { $sticker in
                EditableEditorStickerView(
                    sticker: $sticker
                ) {
                    selectedStickerID = sticker.id
                    stickerDeletePromptID = nil
                } onRequestDelete: {
                    selectedStickerID = sticker.id
                    stickerDeletePromptID = sticker.id
                }
            }

            ForEach(placedStickers.filter { $0.id == stickerDeletePromptID }) { sticker in
                stickerDeleteBubble(for: sticker) {
                    removeSticker(id: sticker.id)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: editorBodyHeight, alignment: .topLeading)
    }

    private func stickerDeleteBubble(for sticker: PlacedEditorSticker, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label("删除", systemImage: "trash")
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background(Color.black.opacity(0.82))
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.16), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .position(
            x: sticker.position.x,
            y: sticker.deleteBubbleY
        )
        .transition(.scale(scale: 0.86).combined(with: .opacity))
        .zIndex(1)
    }

    private var stickerPickerOverlay: some View {
        ZStack {
            Button {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.74)) {
                    isStickerPickerPresented = false
                }
            } label: {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
            }
            .buttonStyle(.plain)

            VStack {
                Spacer()

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("贴纸")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(Theme.Colors.text)

                        Spacer()

                        Button {
                            withAnimation(.spring(response: 0.30, dampingFraction: 0.74)) {
                                isStickerPickerPresented = false
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .black))
                                .foregroundStyle(Theme.Colors.text)
                                .frame(width: 34, height: 34)
                                .background(
                                    QMemoGlassBackground(
                                        shape: Circle(),
                                        tintOpacity: 0.18,
                                        fallbackFillOpacity: 0.82,
                                        strokeOpacity: 0.62,
                                        lineOpacity: 0.10
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    ScrollView {
                        LazyVGrid(columns: stickerPickerColumns, spacing: 12) {
                            ForEach(Self.editorStickerOptions) { sticker in
                                Button {
                                    addSticker(assetName: sticker.assetName)
                                } label: {
                                    VStack(spacing: 8) {
                                        Image(sticker.assetName)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 64, height: 64)

                                        Text(sticker.title)
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(Theme.Colors.text)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.78)
                                    }
                                    .frame(height: 98)
                                    .frame(maxWidth: .infinity)
                                    .background(Theme.Colors.surfaceStrong.opacity(0.58))
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(.white.opacity(0.72), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .scrollIndicators(.hidden)
                    .frame(maxHeight: 226)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    QMemoGlassBackground(
                        shape: RoundedRectangle(cornerRadius: 30, style: .continuous),
                        tintOpacity: 0.20,
                        fallbackFillOpacity: 0.82,
                        strokeOpacity: 0.66,
                        lineOpacity: 0.12
                    )
                )
                .shadow(color: Theme.Colors.shadow.opacity(0.18), radius: 24, y: 10)
                .padding(.horizontal, 20)
                .padding(.bottom, 96)
            }
        }
        .transition(.formatPanelReveal)
    }

    private var formatPanel: some View {
        EditorFormatPanelView(
            selectedBlockStyle: selectedBlockStyle,
            activeInlineStyles: activeInlineStyles,
            onSelectBlockStyle: selectBlockStyle,
            onToggleInlineStyle: toggleInlineStyle
        ) {
            withAnimation(.spring(response: 0.30, dampingFraction: 0.74)) {
                isFormatPanelPresented = false
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            QMemoGlassBackground(
                shape: RoundedRectangle(cornerRadius: 30, style: .continuous),
                tintOpacity: 0.20,
                fallbackFillOpacity: 0.82,
                strokeOpacity: 0.66,
                lineOpacity: 0.12
            )
        )
        .shadow(color: Theme.Colors.shadow.opacity(0.18), radius: 24, y: 10)
    }

    private var functionPanel: some View {
        HStack(spacing: 12) {
            Label {
                Text(category.title)
                    .font(.system(size: 17, weight: .black))
            } icon: {
                Image(category.iconAsset)
                    .resizable()
                    .frame(width: 28, height: 28)
            }
            .foregroundStyle(Theme.Colors.text)
            .labelStyle(.titleAndIcon)

            Spacer(minLength: 6)

            HStack(spacing: 0) {
                Button {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.74)) {
                        isStickerPickerPresented = false
                        isFormatPanelPresented = true
                    }
                } label: {
                    Text("格式")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 126, height: 38)
                }
                .accessibilityLabel("格式")

                Divider()
                    .frame(height: 28)

                Button {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.74)) {
                        isFormatPanelPresented = false
                        isStickerPickerPresented = true
                    }
                } label: {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 52, height: 38)
                }
                .accessibilityLabel("贴纸")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.Colors.text)
            .background(Color(.secondarySystemFill))
            .clipShape(Capsule())
        }
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .frame(height: 54)
        .background(
            QMemoGlassBackground(
                shape: Capsule(),
                tintOpacity: 0.20,
                fallbackFillOpacity: 0.78,
                strokeOpacity: 0.66,
                lineOpacity: 0.12
            )
        )
    }

    private func persistDraftIfNeeded() {
        guard !shouldSkipPersistOnDisappear else { return }
        guard memo != nil || hasEditableDraftContent else { return }

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let storedTitle = cleanTitle.isEmpty ? "未命名便签" : cleanTitle
        let storedStickers = placedStickers.map(\.memoSticker)

        if let memo {
            guard
                storedTitle != memo.title
                    || cleanContent != memo.content
                    || isPinned != memo.isPinned
                    || storedStickers != memo.stickers
            else {
                return
            }

            store.update(
                memo,
                title: storedTitle,
                content: cleanContent,
                isPinned: isPinned,
                stickers: storedStickers
            )
        } else {
            store.create(
                title: storedTitle,
                content: cleanContent,
                category: category,
                isPinned: isPinned,
                stickers: storedStickers
            )
        }
    }

    private func deleteOrDiscardDraft() {
        shouldSkipPersistOnDisappear = true
        if let memo {
            store.delete(memo)
        }
        dismiss()
    }

    private func requestDeleteConfirmation() {
        withAnimation(.easeOut(duration: 0.18)) {
            isDeleteConfirmationPresented = true
        }
    }

    private func confirmDeleteOrDiscardDraft() {
        withAnimation(.easeOut(duration: 0.18)) {
            isDeleteConfirmationPresented = false
        }
        deleteOrDiscardDraft()
    }

    private func recordUndoSnapshot(title previousTitle: String, content previousContent: String) {
        guard !isApplyingUndo else { return }

        let previousSnapshot = MemoEditorSnapshot(title: previousTitle, content: previousContent)
        let currentSnapshot = MemoEditorSnapshot(title: title, content: content)
        guard previousSnapshot != currentSnapshot else { return }
        guard undoStack.last != previousSnapshot else { return }

        isUndoControlVisible = true
        undoStack.append(previousSnapshot)
        if undoStack.count > 60 {
            undoStack.removeFirst(undoStack.count - 60)
        }
    }

    private func undoLastInput() {
        guard let snapshot = undoStack.popLast() else { return }

        isApplyingUndo = true
        title = snapshot.title
        content = snapshot.content

        DispatchQueue.main.async {
            isApplyingUndo = false
        }
    }

    private func selectBlockStyle(_ blockStyle: EditorBlockStyle) {
        selectedBlockStyle = blockStyle
        pendingFormatCommand = EditorFormatCommand(kind: .block(blockStyle))

        if blockStyle.activatesBoldInlineStyle {
            activeInlineStyles.insert(.bold)
        } else {
            activeInlineStyles.remove(.bold)
        }
    }

    private func toggleInlineStyle(_ inlineStyle: EditorInlineStyle) {
        let shouldActivate = !activeInlineStyles.contains(inlineStyle)

        if activeInlineStyles.contains(inlineStyle) {
            activeInlineStyles.remove(inlineStyle)
        } else {
            activeInlineStyles.insert(inlineStyle)
        }

        pendingFormatCommand = EditorFormatCommand(kind: .inline(inlineStyle, isActive: shouldActivate))
    }

    private func addSticker(assetName: String) {
        let sticker = PlacedEditorSticker(assetName: assetName)
        placedStickers.append(sticker)
        selectedStickerID = sticker.id
        stickerDeletePromptID = nil

        withAnimation(.spring(response: 0.30, dampingFraction: 0.74)) {
            isStickerPickerPresented = false
        }
    }

    private func removeSticker(id: UUID) {
        withAnimation(.easeOut(duration: 0.16)) {
            placedStickers.removeAll { $0.id == id }
            if selectedStickerID == id {
                selectedStickerID = nil
            }
            if stickerDeletePromptID == id {
                stickerDeletePromptID = nil
            }
        }
    }

    private static let metadataDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M/d HH:mm"
        return formatter
    }()

    private static let editorStickerOptions: [EditorStickerOption] = [
        EditorStickerOption(assetName: "EditorStickerMP3", title: "MP3"),
        EditorStickerOption(assetName: "EditorStickerEnvelope", title: "信封"),
        EditorStickerOption(assetName: "EditorStickerCoffee", title: "咖啡"),
        EditorStickerOption(assetName: "EditorStickerWeather", title: "天气"),
        EditorStickerOption(assetName: "EditorStickerBackpack", title: "小书包"),
        EditorStickerOption(assetName: "EditorStickerBunnyDoll", title: "小兔玩偶"),
        EditorStickerOption(assetName: "EditorStickerBearDoll", title: "小熊玩偶"),
        EditorStickerOption(assetName: "EditorStickerPolaroid", title: "拍立得"),
        EditorStickerOption(assetName: "EditorStickerCalendar", title: "日历"),
        EditorStickerOption(assetName: "EditorStickerCrystalBall", title: "水晶球"),
        EditorStickerOption(assetName: "EditorStickerBrush", title: "画笔"),
        EditorStickerOption(assetName: "EditorStickerPhotoFrame", title: "相框"),
        EditorStickerOption(assetName: "EditorStickerPenCup", title: "笔筒"),
        EditorStickerOption(assetName: "EditorStickerHeadphones", title: "耳机"),
        EditorStickerOption(assetName: "EditorStickerMushroomHouse", title: "蘑菇屋"),
        EditorStickerOption(assetName: "EditorStickerYogurt", title: "酸奶"),
        EditorStickerOption(assetName: "EditorStickerMagicWand", title: "魔法棒"),
        EditorStickerOption(assetName: "EditorStickerFlowerBasket", title: "花篮")
    ]
}

private struct MemoEditorSnapshot: Equatable {
    let title: String
    let content: String
}

private enum EditorBlockStyle: String, CaseIterable {
    case title
    case subtitle
    case caption
    case body
    case monospace

    var bodyFontSize: CGFloat {
        switch self {
        case .title:
            20
        case .subtitle:
            16
        case .caption:
            18
        case .body:
            14
        case .monospace:
            14
        }
    }

    var bodyFontWeight: UIFont.Weight {
        switch self {
        case .title, .subtitle, .caption:
            .semibold
        case .body, .monospace:
            .regular
        }
    }

    var activatesBoldInlineStyle: Bool {
        false
    }
}

private enum EditorInlineStyle: String, Hashable {
    case bold
    case italic
    case underline
    case strikethrough
}

private struct EditorStickerOption: Identifiable {
    let assetName: String
    let title: String

    var id: String {
        assetName
    }
}

private struct FormatPanelRevealModifier: ViewModifier {
    let progress: CGFloat

    func body(content: Content) -> some View {
        content
            .scaleEffect(
                x: 0.32 + 0.68 * progress,
                y: 0.72 + 0.28 * progress,
                anchor: .bottom
            )
            .offset(y: 18 * (1 - progress))
    }
}

private extension AnyTransition {
    static var formatPanelReveal: AnyTransition {
        .modifier(
            active: FormatPanelRevealModifier(progress: 0),
            identity: FormatPanelRevealModifier(progress: 1)
        )
        .combined(with: .opacity)
    }
}

private struct EditorFormatPanelView: View {
    let selectedBlockStyle: EditorBlockStyle
    let activeInlineStyles: Set<EditorInlineStyle>
    let onSelectBlockStyle: (EditorBlockStyle) -> Void
    let onToggleInlineStyle: (EditorInlineStyle) -> Void
    let onDismiss: () -> Void

    private let textStyles = [
        EditorTextStyleOption(style: .title, title: "标题", font: .system(size: 20, weight: .semibold)),
        EditorTextStyleOption(style: .caption, title: "副标题", font: .system(size: 18, weight: .semibold)),
        EditorTextStyleOption(style: .subtitle, title: "小标题", font: .system(size: 16, weight: .semibold)),
        EditorTextStyleOption(style: .body, title: "正文", font: .system(size: 14, weight: .regular)),
        EditorTextStyleOption(style: .monospace, title: "等宽样式", font: .system(size: 14, weight: .regular, design: .monospaced))
    ]
    private let inlineStyles = [
        EditorInlineStyleOption(style: .bold, title: "加粗", assetName: "FormatBold"),
        EditorInlineStyleOption(style: .italic, title: "倾斜", assetName: "FormatItalic"),
        EditorInlineStyleOption(style: .underline, title: "下划线", assetName: "FormatUnderline"),
        EditorInlineStyleOption(style: .strikethrough, title: "划线", assetName: "FormatStrikethrough")
    ]
    private let selectedFill = Color(hex: "FDE8A4")
    private let selectedForeground = Color(hex: "F1920D")

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Text("格式")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Theme.Colors.text)

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Theme.Colors.text)
                        .frame(width: 34, height: 34)
                        .background(
                            QMemoGlassBackground(
                                shape: Circle(),
                                tintOpacity: 0.18,
                                fallbackFillOpacity: 0.82,
                                strokeOpacity: 0.62,
                                lineOpacity: 0.10
                            )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭")
            }
            .padding(.horizontal, 18)

            HStack(spacing: 0) {
                ForEach(textStyles) { option in
                    let isSelected = selectedBlockStyle == option.style

                    Button {
                        withAnimation(.easeOut(duration: 0.14)) {
                            onSelectBlockStyle(option.style)
                        }
                    } label: {
                        Text(option.title)
                            .font(option.font)
                            .foregroundStyle(isSelected ? selectedForeground : Color.primary.opacity(0.68))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(
                                Capsule()
                                    .fill(isSelected ? selectedFill : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.title)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)

            HStack(spacing: 12) {
                HStack(spacing: 0) {
                    ForEach(Array(inlineStyles.enumerated()), id: \.element.id) { index, item in
                        let isSelected = activeInlineStyles.contains(item.style)

                        formatSegmentButton(
                            assetName: item.assetName,
                            accessibilityLabel: item.title,
                            isSelected: isSelected,
                            width: nil
                        ) {
                            withAnimation(.easeOut(duration: 0.12)) {
                                onToggleInlineStyle(item.style)
                            }
                        }

                        if index < inlineStyles.count - 1 {
                            Divider()
                                .frame(height: 40)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .background(Color(.quaternarySystemFill))
                .clipShape(Capsule())

                HStack(spacing: 0) {
                    formatSegmentButton(
                        assetName: "FormatTextBackground",
                        accessibilityLabel: "文本背景",
                        isSelected: false,
                        width: 50
                    ) {}

                    Divider()
                        .frame(height: 40)

                    Button {} label: {
                        Circle()
                            .fill(Color.orange)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 1)
                            )
                            .frame(width: 24, height: 24)
                            .frame(width: 50, height: 48)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("背景颜色")
                }
                .background(Color(.quaternarySystemFill))
                .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func formatSegmentButton(
        assetName: String,
        accessibilityLabel: String,
        isSelected: Bool,
        width: CGFloat? = 50,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(assetName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(isSelected ? selectedForeground : Color.primary.opacity(0.64))
                .frame(width: 24, height: 24)
                .frame(width: width, height: 48)
                .frame(maxWidth: width == nil ? .infinity : nil)
                .background(isSelected ? selectedFill : Color.clear)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct EditorTextStyleOption: Identifiable {
    let style: EditorBlockStyle
    let title: String
    let font: Font

    var id: String {
        style.rawValue
    }
}

private struct EditorInlineStyleOption: Identifiable {
    let style: EditorInlineStyle
    let title: String
    let assetName: String

    var id: String {
        style.rawValue
    }
}

private struct EditorFormatCommand: Equatable {
    let id = UUID()
    let kind: Kind

    enum Kind: Equatable {
        case block(EditorBlockStyle)
        case inline(EditorInlineStyle, isActive: Bool)
    }
}

private struct PlacedEditorSticker: Identifiable, Equatable {
    private static let baseSize: CGFloat = 120
    private static let wrapPadding: CGFloat = 4
    private static let wrapVisualScale: CGFloat = 1.02

    let id: UUID
    let assetName: String
    var position: CGPoint = CGPoint(x: 254, y: 184)
    var scale: CGFloat = 1
    var rotation: Angle = .zero

    init(
        id: UUID = UUID(),
        assetName: String,
        position: CGPoint = CGPoint(x: 254, y: 184),
        scale: CGFloat = 1,
        rotation: Angle = .zero
    ) {
        self.id = id
        self.assetName = assetName
        self.position = position
        self.scale = scale
        self.rotation = rotation
    }

    init(memoSticker: MemoSticker) {
        self.init(
            id: memoSticker.id,
            assetName: memoSticker.assetName,
            position: CGPoint(x: memoSticker.positionX, y: memoSticker.positionY),
            scale: CGFloat(memoSticker.scale),
            rotation: .degrees(memoSticker.rotationDegrees)
        )
    }

    var displaySize: CGFloat {
        Self.baseSize * scale
    }

    var textExclusionPaths: [UIBezierPath] {
        EditorStickerWrapShapeCache.shared.normalizedBandRects(for: assetName).map { normalizedRect in
            let displayRect = CGRect(
                x: position.x - displaySize / 2 + normalizedRect.minX * displaySize,
                y: position.y - displaySize / 2 + normalizedRect.minY * displaySize,
                width: normalizedRect.width * displaySize,
                height: normalizedRect.height * displaySize
            )
                .insetBy(dx: -Self.wrapPadding, dy: -Self.wrapPadding)

            let scaledRect = displayRect.insetBy(
                dx: -(displayRect.width * (Self.wrapVisualScale - 1)) / 2,
                dy: -(displayRect.height * (Self.wrapVisualScale - 1)) / 2
            )
            let path = UIBezierPath(rect: scaledRect)

            guard abs(rotation.degrees) > 0.1 else {
                return path
            }

            var transform = CGAffineTransform.identity
            transform = transform.translatedBy(x: position.x, y: position.y)
            transform = transform.rotated(by: CGFloat(rotation.radians))
            transform = transform.translatedBy(x: -position.x, y: -position.y)
            path.apply(transform)
            return path
        }
    }

    var deleteBubbleY: CGFloat {
        let preferredY = position.y - displaySize / 2 - 24
        if preferredY < 22 {
            return position.y + displaySize / 2 + 24
        }

        return preferredY
    }

    var memoSticker: MemoSticker {
        MemoSticker(
            id: id,
            assetName: assetName,
            positionX: Double(position.x),
            positionY: Double(position.y),
            scale: Double(scale),
            rotationDegrees: rotation.degrees
        )
    }
}

private final class EditorStickerWrapShapeCache {
    static let shared = EditorStickerWrapShapeCache()

    private let alphaThreshold: UInt8 = 18
    private let bandCount = 18
    private var cachedRects: [String: [CGRect]] = [:]

    func normalizedBandRects(for assetName: String) -> [CGRect] {
        if let rects = cachedRects[assetName] {
            return rects
        }

        let rects = buildNormalizedBandRects(for: assetName)
        cachedRects[assetName] = rects
        return rects
    }

    private func buildNormalizedBandRects(for assetName: String) -> [CGRect] {
        guard
            let image = UIImage(named: assetName),
            let cgImage = image.cgImage,
            let alphaData = alphaData(from: cgImage)
        else {
            return [CGRect(x: 0, y: 0, width: 1, height: 1)]
        }

        let imageWidth = cgImage.width
        let imageHeight = cgImage.height
        let fittedRect = fittedImageRect(width: imageWidth, height: imageHeight)
        let rowsPerBand = max(1, Int(ceil(Double(imageHeight) / Double(bandCount))))
        var rects: [CGRect] = []

        for bandStartY in stride(from: 0, to: imageHeight, by: rowsPerBand) {
            let bandEndY = min(imageHeight, bandStartY + rowsPerBand)
            var minX = imageWidth
            var maxX = -1
            var minY = imageHeight
            var maxY = -1

            for y in bandStartY..<bandEndY {
                for x in 0..<imageWidth {
                    let alphaIndex = (y * imageWidth + x) * 4 + 3
                    guard alphaData[alphaIndex] > alphaThreshold else { continue }

                    minX = min(minX, x)
                    maxX = max(maxX, x)
                    minY = min(minY, y)
                    maxY = max(maxY, y)
                }
            }

            guard maxX >= minX, maxY >= minY else { continue }

            let normalizedRect = CGRect(
                x: fittedRect.minX + (CGFloat(minX) / CGFloat(imageWidth)) * fittedRect.width,
                y: fittedRect.minY + (CGFloat(minY) / CGFloat(imageHeight)) * fittedRect.height,
                width: (CGFloat(maxX - minX + 1) / CGFloat(imageWidth)) * fittedRect.width,
                height: (CGFloat(maxY - minY + 1) / CGFloat(imageHeight)) * fittedRect.height
            )
            rects.append(normalizedRect)
        }

        return rects.isEmpty ? [CGRect(x: 0, y: 0, width: 1, height: 1)] : rects
    }

    private func alphaData(from cgImage: CGImage) -> [UInt8]? {
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var data = [UInt8](repeating: 0, count: height * bytesPerRow)

        guard let context = CGContext(
            data: &data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return data
    }

    private func fittedImageRect(width: Int, height: Int) -> CGRect {
        let imageWidth = CGFloat(width)
        let imageHeight = CGFloat(height)
        guard imageWidth > 0, imageHeight > 0 else {
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        }

        let aspect = imageWidth / imageHeight
        if aspect >= 1 {
            let fittedHeight = 1 / aspect
            return CGRect(x: 0, y: (1 - fittedHeight) / 2, width: 1, height: fittedHeight)
        }

        let fittedWidth = aspect
        return CGRect(x: (1 - fittedWidth) / 2, y: 0, width: fittedWidth, height: 1)
    }
}

private struct EditableEditorStickerView: View {
    @Binding var sticker: PlacedEditorSticker
    let onSelect: () -> Void
    let onRequestDelete: () -> Void

    @State private var dragStartPosition: CGPoint?
    @GestureState private var gestureScale: CGFloat = 1
    @GestureState private var gestureRotation: Angle = .zero

    var body: some View {
        let drag = DragGesture()
            .onChanged { value in
                let startPosition = dragStartPosition ?? sticker.position
                dragStartPosition = startPosition
                sticker.position = CGPoint(
                    x: startPosition.x + value.translation.width,
                    y: startPosition.y + value.translation.height
                )
            }
            .onEnded { _ in
                dragStartPosition = nil
            }

        let magnify = MagnificationGesture()
            .updating($gestureScale) { value, state, _ in
                state = value
            }
            .onEnded { value in
                sticker.scale = min(max(sticker.scale * value, 0.45), 2.2)
            }

        let rotate = RotationGesture()
            .updating($gestureRotation) { value, state, _ in
                state = value
            }
            .onEnded { value in
                sticker.rotation += value
            }

        Image(sticker.assetName)
            .resizable()
            .scaledToFit()
            .frame(width: 120, height: 120)
            .scaleEffect(min(max(sticker.scale * gestureScale, 0.45), 2.2))
            .rotationEffect(sticker.rotation + gestureRotation)
            .contentShape(Rectangle())
            .position(
                x: sticker.position.x,
                y: sticker.position.y
            )
            .onTapGesture {
                onSelect()
            }
            .gesture(drag.simultaneously(with: magnify).simultaneously(with: rotate))
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.55)
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.78)) {
                            onRequestDelete()
                        }
                    }
            )
            .accessibilityLabel("贴纸")
    }
}

private struct EditorMoreMenuButton: UIViewRepresentable {
    let isPinned: Bool
    let onTogglePin: () -> Void
    let onDelete: () -> Void

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(configuration: buttonConfiguration())
        button.showsMenuAsPrimaryAction = true
        button.changesSelectionAsPrimaryAction = false
        button.accessibilityLabel = "更多"
        context.coordinator.configure(button)
        return button
    }

    func updateUIView(_ button: UIButton, context: Context) {
        context.coordinator.parent = self
        button.configuration = buttonConfiguration()
        context.coordinator.configure(button)
    }

    private func buttonConfiguration() -> UIButton.Configuration {
        var configuration: UIButton.Configuration
        if #available(iOS 26.0, *) {
            configuration = .glass()
        } else {
            configuration = .bordered()
        }

        configuration.image = UIImage(systemName: "ellipsis")
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 21, weight: .bold)
        configuration.baseForegroundColor = UIColor(red: 0x49 / 255, green: 0x39 / 255, blue: 0x2F / 255, alpha: 1)
        configuration.cornerStyle = .capsule
        configuration.buttonSize = .large
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        if #available(iOS 16.0, *) {
            configuration.indicator = .none
        }
        return configuration
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator {
        var parent: EditorMoreMenuButton

        init(parent: EditorMoreMenuButton) {
            self.parent = parent
        }

        func configure(_ button: UIButton) {
            let isPinned = parent.isPinned
            let pinAction = UIAction(title: isPinned ? "取消置顶" : "置顶", image: UIImage(named: isPinned ? "ActionUnpin" : "ActionPin")) { [weak self] _ in
                self?.parent.onTogglePin()
            }
            let deleteAction = UIAction(title: "删除", image: UIImage(named: "ActionDelete"), attributes: .destructive) { [weak self] _ in
                self?.parent.onDelete()
            }
            button.menu = UIMenu(children: [pinAction, deleteAction])
        }
    }
}

private struct MemoBodyTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var calculatedHeight: CGFloat
    @Binding var selectedBlockStyle: EditorBlockStyle
    @Binding var activeInlineStyles: Set<EditorInlineStyle>
    @Binding var pendingFormatCommand: EditorFormatCommand?

    let textColor: UIColor
    let lineSpacing: CGFloat
    let exclusionPaths: [UIBezierPath]

    private static let blockStyleAttribute = NSAttributedString.Key("QMemoBlockStyle")
    private static let inlineStylesAttribute = NSAttributedString.Key("QMemoInlineStyles")
    private static let lineHeightRatio: CGFloat = 1.25

    func makeUIView(context: Context) -> RichTextView {
        let textView = RichTextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.isOpaque = false
        textView.textColor = textColor
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.contentInset = .zero
        textView.scrollIndicatorInsets = .zero
        textView.isScrollEnabled = false
        textView.alwaysBounceVertical = false
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.typingAttributes = attributes(blockStyle: selectedBlockStyle, inlineStyles: activeInlineStyles)
        textView.textContainer.exclusionPaths = boundedExclusionPaths(for: textView)
        textView.attributedText = attributedString(for: text)
        textView.typingAttributes = attributes(blockStyle: selectedBlockStyle, inlineStyles: activeInlineStyles)
        return textView
    }

    func updateUIView(_ textView: RichTextView, context: Context) {
        context.coordinator.parent = self
        textView.textColor = textColor
        textView.isScrollEnabled = false
        textView.textContainer.exclusionPaths = boundedExclusionPaths(for: textView)

        defer {
            updateHeight(for: textView)
        }

        if textView.text != text {
            let selectedRange = textView.selectedRange
            textView.attributedText = attributedString(for: text)
            textView.selectedRange = clampedRange(selectedRange, in: text)
        }

        if let command = pendingFormatCommand,
           context.coordinator.appliedFormatCommandID != command.id {
            apply(command, to: textView, context: context)
            context.coordinator.appliedFormatCommandID = command.id
        } else {
            textView.typingAttributes = attributes(blockStyle: selectedBlockStyle, inlineStyles: activeInlineStyles)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func apply(_ command: EditorFormatCommand, to textView: UITextView, context: Context) {
        let selectedRange = textView.selectedRange
        let targetRange = formatTargetRange(in: textView)
        let mutableText = NSMutableAttributedString(attributedString: textView.attributedText ?? attributedString(for: textView.text))
        let nextAttributes = attributes(blockStyle: selectedBlockStyle, inlineStyles: activeInlineStyles)

        if targetRange.length > 0 {
            apply(command, to: mutableText, in: clampedRange(targetRange, in: textView.text))
            textView.attributedText = mutableText
            textView.selectedRange = clampedRange(selectedRange, in: textView.text)
            text = mutableText.string
        }

        textView.typingAttributes = nextAttributes
    }

    private func apply(_ command: EditorFormatCommand, to text: NSMutableAttributedString, in range: NSRange) {
        guard range.length > 0 else { return }

        let runs = attributeRuns(in: text, range: range)

        for run in runs {
            var currentInlineStyles = run.inlineStyles
            let nextBlockStyle: EditorBlockStyle

            switch command.kind {
            case .block(let blockStyle):
                nextBlockStyle = blockStyle
                if blockStyle.activatesBoldInlineStyle {
                    currentInlineStyles.insert(.bold)
                } else {
                    currentInlineStyles.remove(.bold)
                }
            case .inline(let inlineStyle, let isActive):
                nextBlockStyle = run.blockStyle
                if isActive {
                    currentInlineStyles.insert(inlineStyle)
                } else {
                    currentInlineStyles.remove(inlineStyle)
                }
            }

            text.setAttributes(
                attributes(blockStyle: nextBlockStyle, inlineStyles: currentInlineStyles),
                range: run.range
            )
        }
    }

    private func attributeRuns(
        in text: NSAttributedString,
        range targetRange: NSRange
    ) -> [(range: NSRange, blockStyle: EditorBlockStyle, inlineStyles: Set<EditorInlineStyle>)] {
        var runs: [(NSRange, EditorBlockStyle, Set<EditorInlineStyle>)] = []

        text.enumerateAttributes(in: targetRange, options: []) { attributes, effectiveRange, _ in
            let affectedRange = NSIntersectionRange(effectiveRange, targetRange)
            guard affectedRange.length > 0 else { return }

            runs.append((affectedRange, blockStyle(from: attributes), inlineStyles(from: attributes)))
        }

        return runs
    }

    private func formatTargetRange(in textView: UITextView) -> NSRange {
        let selectedRange = clampedRange(textView.selectedRange, in: textView.text)
        let nsText = textView.text as NSString

        if selectedRange.length > 0 {
            if selectedRange.length >= nsText.length,
               nsText.length > 0,
               !textView.isFirstResponder {
                return NSRange(location: 0, length: 0)
            }

            return selectedRange
        }

        guard nsText.length > 0 else {
            return NSRange(location: selectedRange.location, length: 0)
        }

        if selectedRange.location == nsText.length,
           nsText.substring(from: max(nsText.length - 1, 0)) == "\n" {
            return NSRange(location: selectedRange.location, length: 0)
        }

        return visibleParagraphRange(
            in: nsText,
            at: min(selectedRange.location, nsText.length - 1)
        )
    }

    private func visibleParagraphRange(in text: NSString, at location: Int) -> NSRange {
        let paragraphRange = text.paragraphRange(for: NSRange(location: location, length: 0))
        guard paragraphRange.length > 0 else { return paragraphRange }

        let lastIndex = paragraphRange.location + paragraphRange.length - 1
        let includesTrailingNewline = text.substring(with: NSRange(location: lastIndex, length: 1)) == "\n"
        guard includesTrailingNewline else { return paragraphRange }

        return NSRange(
            location: paragraphRange.location,
            length: max(paragraphRange.length - 1, 0)
        )
    }

    private func attributes(
        blockStyle: EditorBlockStyle,
        inlineStyles: Set<EditorInlineStyle>
    ) -> [NSAttributedString.Key: Any] {
        let font = font(blockStyle: blockStyle, inlineStyles: inlineStyles)
        let paragraphStyle = paragraphStyle(font: font)

        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle,
            .baselineOffset: Self.baselineOffset(for: font),
            Self.blockStyleAttribute: blockStyle.rawValue,
            Self.inlineStylesAttribute: inlineStyles.map(\.rawValue).sorted().joined(separator: ",")
        ]

        if inlineStyles.contains(.underline) {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }

        if inlineStyles.contains(.strikethrough) {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }

        return attributes
    }

    private func paragraphStyle(font: UIFont) -> NSMutableParagraphStyle {
        let lineHeight = Self.lineHeight(for: font)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = lineHeight
        paragraphStyle.maximumLineHeight = lineHeight
        paragraphStyle.lineSpacing = 0
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.paragraphSpacing = 0

        return paragraphStyle
    }

    private static func lineHeight(for font: UIFont) -> CGFloat {
        ceil(max(font.lineHeight, font.pointSize * lineHeightRatio) / 4) * 4
    }

    private static func baselineOffset(for font: UIFont) -> CGFloat {
        (lineHeight(for: font) - font.lineHeight) / 2
    }

    private static func baselineOffset(from attributes: [NSAttributedString.Key: Any], font: UIFont) -> CGFloat {
        if let offset = attributes[.baselineOffset] as? CGFloat {
            return offset
        }

        if let offset = attributes[.baselineOffset] as? NSNumber {
            return CGFloat(offset.doubleValue)
        }

        return baselineOffset(for: font)
    }

    private func font(blockStyle: EditorBlockStyle, inlineStyles: Set<EditorInlineStyle>) -> UIFont {
        let weight = inlineStyles.contains(.bold) ? UIFont.Weight.bold : blockStyle.bodyFontWeight
        let baseFont: UIFont

        if blockStyle == .monospace {
            baseFont = .monospacedSystemFont(ofSize: blockStyle.bodyFontSize, weight: weight)
        } else {
            baseFont = .systemFont(ofSize: blockStyle.bodyFontSize, weight: weight)
        }

        guard inlineStyles.contains(.italic),
              let descriptor = baseFont.fontDescriptor.withSymbolicTraits(.traitItalic)
        else {
            return baseFont
        }

        return UIFont(descriptor: descriptor, size: blockStyle.bodyFontSize)
    }

    private func attributedString(for text: String) -> NSAttributedString {
        NSAttributedString(
            string: text,
            attributes: attributes(blockStyle: .body, inlineStyles: [])
        )
    }

    private func blockStyle(from attributes: [NSAttributedString.Key: Any]) -> EditorBlockStyle {
        guard let rawValue = attributes[Self.blockStyleAttribute] as? String,
              let blockStyle = EditorBlockStyle(rawValue: rawValue)
        else {
            return .body
        }

        return blockStyle
    }

    private func inlineStyles(from attributes: [NSAttributedString.Key: Any]) -> Set<EditorInlineStyle> {
        guard let rawValue = attributes[Self.inlineStylesAttribute] as? String,
              !rawValue.isEmpty
        else {
            return []
        }

        return Set(rawValue.split(separator: ",").compactMap { EditorInlineStyle(rawValue: String($0)) })
    }

    private func clampedRange(_ range: NSRange, in text: String) -> NSRange {
        let count = (text as NSString).length
        let location = min(range.location, count)
        let length = min(range.length, count - location)
        return NSRange(location: location, length: length)
    }

    private func updateHeight(for textView: UITextView) {
        let width = textView.bounds.width
        guard width > 0 else { return }

        let size = textView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        let nextHeight = ceil(size.height)
        guard abs(calculatedHeight - nextHeight) > 0.5 else { return }

        DispatchQueue.main.async {
            calculatedHeight = nextHeight
        }
    }

    private func boundedExclusionPaths(for textView: UITextView) -> [UIBezierPath] {
        let containerWidth = textView.bounds.width
        guard containerWidth > 0 else { return [] }

        let containerRect = CGRect(
            x: 0,
            y: 0,
            width: containerWidth,
            height: max(textView.bounds.height, calculatedHeight)
        )

        return exclusionPaths.compactMap { path in
            guard path.bounds.intersects(containerRect) else {
                return nil
            }

            return path
        }
    }

    final class RichTextView: UITextView {
        override func caretRect(for position: UITextPosition) -> CGRect {
            var rect = super.caretRect(for: position)
            let activeFont = typingAttributes[.font] as? UIFont
                ?? font
                ?? UIFont.systemFont(ofSize: EditorBlockStyle.body.bodyFontSize)
            let caretHeight = activeFont.lineHeight

            if let textRange = textRange(from: beginningOfDocument, to: position) {
                let characterIndex = offset(from: beginningOfDocument, to: textRange.end)
                let storageLength = textStorage.length

                if storageLength > 0 {
                    layoutManager.ensureLayout(for: textContainer)

                    let boundedCharacterIndex = min(max(characterIndex, 0), storageLength - 1)
                    let glyphIndex = layoutManager.glyphIndexForCharacter(at: boundedCharacterIndex)
                    let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
                    rect.origin.y = textContainerInset.top + lineRect.midY - caretHeight / 2
                } else {
                    rect.origin.y = rect.midY - caretHeight / 2
                }
            } else {
                rect.origin.y = rect.midY - caretHeight / 2
            }

            rect.size.height = caretHeight
            return rect
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: MemoBodyTextView
        var appliedFormatCommandID: UUID?

        init(_ parent: MemoBodyTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            parent.updateHeight(for: textView)
            syncSelectionStyle(from: textView)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            syncSelectionStyle(from: textView)
        }

        func syncSelectionStyle(from textView: UITextView) {
            guard let attributedText = textView.attributedText,
                  attributedText.length > 0
            else {
                parent.selectedBlockStyle = .body
                parent.activeInlineStyles = []
                textView.typingAttributes = parent.attributes(blockStyle: .body, inlineStyles: [])
                textView.font = parent.font(blockStyle: .body, inlineStyles: [])
                return
            }

            let selectedRange = textView.selectedRange
            let index = min(max(selectedRange.location - (selectedRange.location == attributedText.length ? 1 : 0), 0), attributedText.length - 1)
            let attributes = attributedText.attributes(at: index, effectiveRange: nil)
            let blockStyle = parent.blockStyle(from: attributes)
            let inlineStyles = parent.inlineStyles(from: attributes)

            if parent.selectedBlockStyle != blockStyle {
                parent.selectedBlockStyle = blockStyle
            }

            if parent.activeInlineStyles != inlineStyles {
                parent.activeInlineStyles = inlineStyles
            }

            textView.typingAttributes = parent.attributes(blockStyle: blockStyle, inlineStyles: inlineStyles)
            textView.font = parent.font(blockStyle: blockStyle, inlineStyles: inlineStyles)
        }

    }
}

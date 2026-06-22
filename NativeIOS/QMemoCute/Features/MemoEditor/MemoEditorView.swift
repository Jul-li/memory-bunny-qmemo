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
    @State private var richContentData: Data?
    @State private var isPinned: Bool
    @State private var isCustomNavigationVisible = false
    @State private var bodyTextHeight: CGFloat = 520
    @State private var undoStack: [MemoEditorSnapshot]
    @State private var isApplyingUndo = false
    @State private var isUndoControlVisible = false
    @State private var isStickerPickerPresented = false
    @State private var isFormatPanelPresented = false
    @State private var isToolbarColorPickerPresented = false
    @State private var isDeleteConfirmationPresented = false
    @State private var placedStickers: [PlacedEditorSticker] = []
    @State private var selectedStickerID: UUID?
    @State private var stickerDeletePromptID: UUID?
    @State private var shouldSkipPersistOnDisappear = false
    @State private var savedDraftMemoID: UUID?
    @State private var isSaveConfirmationVisible = false
    @State private var isBodyTextFocused = false
    @State private var editorContentFlushRequestID: UUID?
    @State private var editorContentFlushedRequestID: UUID?
    @State private var pendingConfirmedSaveID: UUID?
    @State private var selectedBlockStyle: EditorBlockStyle = .body
    @State private var activeInlineStyles: Set<EditorInlineStyle> = []
    @State private var activeTextColor: EditorTextColor?
    @State private var pendingFormatCommand: EditorFormatCommand?
    @FocusState private var isTitleFocused: Bool
    private let editorLineSpacing: CGFloat = 32
    private let editorBodyLineSpacing: CGFloat = 8
    private let functionPanelCollapsedWidth: CGFloat = 128
    private let functionPanelHorizontalPadding: CGFloat = 10
    private let functionPanelVisibleItemCount: CGFloat = 6
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
    private var isFunctionPanelExpanded: Bool {
        isTitleFocused
            || isBodyTextFocused
            || isFormatPanelPresented
            || isStickerPickerPresented
            || isToolbarColorPickerPresented
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
        _richContentData = State(initialValue: memo?.richContentData)
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
                        .focused($isTitleFocused)
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

            if isSaveConfirmationVisible {
                ToolbarItem(placement: .confirmationAction) {
                    saveConfirmationButton
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
            showSaveConfirmation()
        }
        .onChange(of: content) { oldValue, _ in
            recordUndoSnapshot(title: title, content: oldValue)
            showSaveConfirmation()
        }
        .onChange(of: richContentData) {
            showSaveConfirmation()
        }
        .onChange(of: isPinned) {
            showSaveConfirmation()
            persistExistingMemoIfNeeded()
        }
        .onChange(of: placedStickers) {
            showSaveConfirmation()
            persistExistingMemoIfNeeded()
        }
        .onChange(of: isTitleFocused) { _, isFocused in
            updateSaveConfirmationVisibility(isFocused)
        }
        .onChange(of: isBodyTextFocused) { _, isFocused in
            updateSaveConfirmationVisibility(isFocused)
        }
        .onChange(of: editorContentFlushedRequestID) { _, flushedRequestID in
            completeConfirmedSaveIfNeeded(flushedRequestID)
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

                if isSaveConfirmationVisible {
                    Button {
                        confirmSave()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .black))
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
                    .accessibilityLabel("确认保存")
                    .buttonStyle(.plain)
                    .transition(.scale(scale: 0.86).combined(with: .opacity))
                }

                if shouldShowMoreButton {
                    editorMoreMenu
                }
            }
            .animation(.spring(response: 0.24, dampingFraction: 0.86), value: isUndoControlVisible)
            .animation(.spring(response: 0.24, dampingFraction: 0.86), value: isSaveConfirmationVisible)
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

    private var saveConfirmationButton: some View {
        Button {
            confirmSave()
        } label: {
            Image(systemName: "checkmark")
        }
        .accessibilityLabel("确认保存")
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

            if isToolbarColorPickerPresented {
                VStack {
                    Spacer()
                    toolbarColorPickerPanel
                        .padding(.trailing, 20)
                        .padding(.bottom, 82)
                }
                .transition(.scale(scale: 0.92, anchor: .bottomTrailing).combined(with: .opacity))
                .animation(.spring(response: 0.24, dampingFraction: 0.78), value: isToolbarColorPickerPresented)
                .zIndex(1)
            }
        }
    }

    private var editorBodyInput: some View {
        MemoBodyTextView(
            text: $content,
            calculatedHeight: $bodyTextHeight,
            richContentData: $richContentData,
            isFocused: $isBodyTextFocused,
            flushedRequestID: $editorContentFlushedRequestID,
            selectedBlockStyle: $selectedBlockStyle,
            activeInlineStyles: $activeInlineStyles,
            activeTextColor: $activeTextColor,
            pendingFormatCommand: $pendingFormatCommand,
            flushRequestID: editorContentFlushRequestID,
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
            activeTextColor: activeTextColor,
            onSelectBlockStyle: selectBlockStyle,
            onToggleInlineStyle: toggleInlineStyle,
            onApplyTextColor: applyTextColor
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
        GeometryReader { proxy in
            let panelWidth = isFunctionPanelExpanded ? proxy.size.width : functionPanelCollapsedWidth
            let toolbarItemWidth = max(
                (proxy.size.width - functionPanelHorizontalPadding * 2) / functionPanelVisibleItemCount,
                44
            )

            ZStack(alignment: .trailing) {
                QMemoGlassBackground(
                    shape: Capsule(),
                    tintOpacity: 0.20,
                    fallbackFillOpacity: 0.78,
                    strokeOpacity: 0.66,
                    lineOpacity: 0.12
                )

                expandedFunctionPanel(itemWidth: toolbarItemWidth)
                    .opacity(isFunctionPanelExpanded ? 1 : 0)
                    .allowsHitTesting(isFunctionPanelExpanded)

                collapsedCategoryContent
                    .opacity(isFunctionPanelExpanded ? 0 : 1)
                    .allowsHitTesting(!isFunctionPanelExpanded)
            }
            .frame(width: panelWidth, height: 54, alignment: .trailing)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(height: 54)
        .animation(.spring(response: 0.30, dampingFraction: 0.78), value: isFunctionPanelExpanded)
    }

    private var collapsedCategoryContent: some View {
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
        .padding(.leading, 16)
        .padding(.trailing, 16)
        .frame(width: functionPanelCollapsedWidth, height: 54, alignment: .center)
    }

    private func expandedFunctionPanel(itemWidth: CGFloat) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                toolbarTextButton("格式", width: itemWidth) {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.74)) {
                        isStickerPickerPresented = false
                        isToolbarColorPickerPresented = false
                        isFormatPanelPresented = true
                    }
                }

                toolbarIconButton(systemName: "face.smiling", accessibilityLabel: "贴纸", width: itemWidth) {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.74)) {
                        isFormatPanelPresented = false
                        isToolbarColorPickerPresented = false
                        isStickerPickerPresented = true
                    }
                }

                toolbarIconButton(systemName: "checklist", accessibilityLabel: "代办", width: itemWidth) {
                    insertTodoItem()
                }

                toolbarAssetButton(
                    assetName: "FormatBold",
                    accessibilityLabel: "加粗",
                    isSelected: activeInlineStyles.contains(.bold),
                    width: itemWidth
                ) {
                    toggleInlineStyle(.bold)
                }

                toolbarAssetButton(
                    assetName: "FormatItalic",
                    accessibilityLabel: "倾斜",
                    isSelected: activeInlineStyles.contains(.italic),
                    width: itemWidth
                ) {
                    toggleInlineStyle(.italic)
                }

                toolbarAssetButton(
                    assetName: "FormatUnderline",
                    accessibilityLabel: "下划线",
                    isSelected: activeInlineStyles.contains(.underline),
                    width: itemWidth
                ) {
                    toggleInlineStyle(.underline)
                }

                toolbarAssetButton(
                    assetName: "FormatStrikethrough",
                    accessibilityLabel: "划线",
                    isSelected: activeInlineStyles.contains(.strikethrough),
                    width: itemWidth
                ) {
                    toggleInlineStyle(.strikethrough)
                }

                toolbarAssetButton(
                    assetName: "FormatTextBackground",
                    accessibilityLabel: "颜色编辑",
                    isSelected: activeTextColor != nil,
                    width: itemWidth
                ) {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
                        isFormatPanelPresented = false
                        isStickerPickerPresented = false
                        isToolbarColorPickerPresented.toggle()
                    }
                }
            }
            .padding(.horizontal, functionPanelHorizontalPadding)
            .buttonStyle(.plain)
            .foregroundStyle(Theme.Colors.text)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, minHeight: 54, maxHeight: 54, alignment: .trailing)
    }

    private var toolbarColorPickerPanel: some View {
        HStack(spacing: 10) {
            ForEach(EditorTextColor.allCases, id: \.self) { textColor in
                Button {
                    applyTextColor(textColor)
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
                        isToolbarColorPickerPresented = false
                    }
                } label: {
                    Circle()
                        .fill(textColor.color)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 1)
                        )
                        .overlay(
                            Circle()
                                .stroke(
                                    activeTextColor == textColor ? Color(hex: "F1920D") : Color.clear,
                                    lineWidth: 2
                                )
                                .padding(-3)
                        )
                        .frame(width: 26, height: 26)
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(textColor.accessibilityLabel)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            QMemoGlassBackground(
                shape: RoundedRectangle(cornerRadius: 22, style: .continuous),
                tintOpacity: 0.20,
                fallbackFillOpacity: 0.82,
                strokeOpacity: 0.62,
                lineOpacity: 0.10
            )
        )
        .shadow(color: Theme.Colors.shadow.opacity(0.14), radius: 18, y: 8)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func toolbarTextButton(
        _ title: String,
        width: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: width, height: 38)
        }
        .accessibilityLabel(title)
    }

    private func toolbarIconButton(
        systemName: String,
        accessibilityLabel: String,
        width: CGFloat = 44,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: width, height: 38)
        }
        .accessibilityLabel(accessibilityLabel)
    }

    private func toolbarAssetButton(
        assetName: String,
        accessibilityLabel: String,
        isSelected: Bool,
        width: CGFloat = 44,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isSelected ? Color(hex: "FDE8A4") : Color.clear)
                    .frame(width: 34, height: 34)

                Image(assetName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(isSelected ? Color(hex: "F1920D") : Color.primary.opacity(0.64))
                    .frame(width: 22, height: 22)
            }
            .frame(width: width, height: 38)
        }
        .accessibilityLabel(accessibilityLabel)
    }

    private func persistDraftIfNeeded() {
        guard !shouldSkipPersistOnDisappear else { return }
        guard memo != nil || hasEditableDraftContent else { return }

        if editableStoredMemo() != nil {
            persistExistingMemoIfNeeded()
            return
        }

        createDraftMemoIfNeeded()
    }

    private func createDraftMemoIfNeeded() {
        guard memo == nil, hasEditableDraftContent else { return }

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let storedTitle = cleanTitle.isEmpty ? "未命名便签" : cleanTitle
        let storedContent = storedContentText(fallback: cleanContent)
        let storedStickers = placedStickers.map(\.memoSticker)

        let createdMemo = store.create(
            title: storedTitle,
            content: storedContent,
            richContentData: richContentData,
            category: category,
            isPinned: isPinned,
            stickers: storedStickers
        )
        savedDraftMemoID = createdMemo.id
    }

    private func persistExistingMemoIfNeeded() {
        guard !shouldSkipPersistOnDisappear, let storedMemo = editableStoredMemo() else { return }

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let storedTitle = cleanTitle.isEmpty ? "未命名便签" : cleanTitle
        let storedContent = storedContentText(fallback: cleanContent)
        let storedStickers = placedStickers.map(\.memoSticker)

        guard
            storedTitle != storedMemo.title
                || storedContent != storedMemo.content
                || richContentData != storedMemo.richContentData
                || isPinned != storedMemo.isPinned
                || storedStickers != storedMemo.stickers
        else {
            return
        }

        store.update(
            storedMemo,
            title: storedTitle,
            content: storedContent,
            richContentData: richContentData,
            isPinned: isPinned,
            stickers: storedStickers
        )
    }

    private func storedContentText(fallback cleanContent: String) -> String {
        guard let richContentData,
              let storedString = try? NSKeyedUnarchiver.unarchivedObject(
                ofClass: NSAttributedString.self,
                from: richContentData
              )
        else {
            return cleanContent
        }

        return storedString.string
    }

    private func editableStoredMemo() -> Memo? {
        if let memo {
            return store.memos.first { $0.id == memo.id } ?? memo
        }

        guard let savedDraftMemoID else { return nil }
        return store.memos.first { $0.id == savedDraftMemoID }
    }

    private func confirmSave() {
        let requestID = UUID()
        pendingConfirmedSaveID = requestID
        editorContentFlushRequestID = requestID
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func completeConfirmedSaveIfNeeded(_ flushedRequestID: UUID?) {
        guard let flushedRequestID, pendingConfirmedSaveID == flushedRequestID else { return }

        persistDraftIfNeeded()
        pendingConfirmedSaveID = nil
        withAnimation(.spring(response: 0.20, dampingFraction: 0.88)) {
            isSaveConfirmationVisible = false
        }
    }

    private func showSaveConfirmation() {
        guard !isSaveConfirmationVisible else { return }

        withAnimation(.spring(response: 0.20, dampingFraction: 0.88)) {
            isSaveConfirmationVisible = true
        }
    }

    private func updateSaveConfirmationVisibility(_ isFocused: Bool) {
        if isFocused {
            showSaveConfirmation()
        } else if !isTitleFocused && !isBodyTextFocused {
            withAnimation(.spring(response: 0.20, dampingFraction: 0.88)) {
                isSaveConfirmationVisible = false
            }
        }
    }

    private func deleteOrDiscardDraft() {
        shouldSkipPersistOnDisappear = true
        if let storedMemo = editableStoredMemo() {
            store.delete(storedMemo)
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

    private func applyTextColor(_ textColor: EditorTextColor) {
        activeTextColor = textColor
        pendingFormatCommand = EditorFormatCommand(kind: .textColor(textColor))
    }

    private func insertTodoItem() {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
            isFormatPanelPresented = false
            isStickerPickerPresented = false
            isToolbarColorPickerPresented = false
        }
        pendingFormatCommand = EditorFormatCommand(kind: .insertText("□ "))
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

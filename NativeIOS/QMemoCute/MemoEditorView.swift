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

private enum EditorTextColor: String, CaseIterable, Hashable {
    case orange
    case blue
    case mint
    case pink
    case purple
    case gray

    var color: Color {
        Color(hex: hexValue)
    }

    var uiColor: UIColor {
        UIColor(
            red: CGFloat(redValue) / 255,
            green: CGFloat(greenValue) / 255,
            blue: CGFloat(blueValue) / 255,
            alpha: 1
        )
    }

    var backgroundUIColor: UIColor {
        uiColor.withAlphaComponent(0.14)
    }

    var accessibilityLabel: String {
        switch self {
        case .orange:
            "橙色"
        case .blue:
            "蓝色"
        case .mint:
            "薄荷绿"
        case .pink:
            "粉色"
        case .purple:
            "紫色"
        case .gray:
            "灰色"
        }
    }

    private var hexValue: String {
        switch self {
        case .orange:
            "FF8A22"
        case .blue:
            "5AA7FF"
        case .mint:
            "44CFA2"
        case .pink:
            "FF8FB3"
        case .purple:
            "A889FF"
        case .gray:
            "8E8E93"
        }
    }

    private var redValue: Int {
        Int(String(hexValue.prefix(2)), radix: 16) ?? 0
    }

    private var greenValue: Int {
        Int(String(hexValue.dropFirst(2).prefix(2)), radix: 16) ?? 0
    }

    private var blueValue: Int {
        Int(String(hexValue.dropFirst(4).prefix(2)), radix: 16) ?? 0
    }

    func matches(_ color: UIColor) -> Bool {
        let current = color.resolvedColor(with: UITraitCollection.current)
        let expected = uiColor.resolvedColor(with: UITraitCollection.current)
        var currentRed: CGFloat = 0
        var currentGreen: CGFloat = 0
        var currentBlue: CGFloat = 0
        var currentAlpha: CGFloat = 0
        var expectedRed: CGFloat = 0
        var expectedGreen: CGFloat = 0
        var expectedBlue: CGFloat = 0
        var expectedAlpha: CGFloat = 0

        guard
            current.getRed(&currentRed, green: &currentGreen, blue: &currentBlue, alpha: &currentAlpha),
            expected.getRed(&expectedRed, green: &expectedGreen, blue: &expectedBlue, alpha: &expectedAlpha)
        else {
            return false
        }

        return abs(currentRed - expectedRed) < 0.01
            && abs(currentGreen - expectedGreen) < 0.01
            && abs(currentBlue - expectedBlue) < 0.01
            && abs(currentAlpha - expectedAlpha) < 0.01
    }
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
    @State private var isColorPickerPresented = false
    @State private var colorPickerPanelProgress: CGFloat = 0
    @State private var visibleColorPickerColors: Set<EditorTextColor> = []
    @State private var colorPickerAnimationID = UUID()

    let selectedBlockStyle: EditorBlockStyle
    let activeInlineStyles: Set<EditorInlineStyle>
    let activeTextColor: EditorTextColor?
    let onSelectBlockStyle: (EditorBlockStyle) -> Void
    let onToggleInlineStyle: (EditorInlineStyle) -> Void
    let onApplyTextColor: (EditorTextColor) -> Void
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
    private let colorPickerSequenceDuration = 0.30
    private let colorPickerSwatchDuration = 0.10
    private let colorPickerOpeningSwatchDelay = 0.02
    private let colorPickerPanelFullWidth: CGFloat = 302
    private let colorPickerPanelHeight: CGFloat = 58
    private var selectedTextColor: EditorTextColor {
        activeTextColor ?? .orange
    }

    private var colorPickerPanelWidth: CGFloat {
        max(colorPickerPanelFullWidth * colorPickerPanelProgress, 0)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
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
                            accessibilityLabel: "文本颜色",
                            isSelected: activeTextColor != nil,
                            width: 50
                        ) {
                            withAnimation(.easeOut(duration: 0.12)) {
                                onApplyTextColor(selectedTextColor)
                            }
                        }

                        Divider()
                            .frame(height: 40)

                        Button {
                            toggleColorPicker()
                        } label: {
                            Circle()
                                .fill(selectedTextColor.color)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 1)
                                )
                                .frame(width: 24, height: 24)
                                .frame(width: 50, height: 48)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("选择颜色")
                    }
                    .background(Color(.quaternarySystemFill))
                    .clipShape(Capsule())
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 14)
            }
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(
                Color.black.opacity(0.001)
                    .onTapGesture {
                        closeColorPicker()
                    }
            )

            if isColorPickerPresented {
                colorPickerPanel
                    .padding(.trailing, 12)
                    .padding(.bottom, 66)
            }
        }
    }

    private func closeColorPicker() {
        guard isColorPickerPresented else { return }

        let animationID = UUID()
        colorPickerAnimationID = animationID
        let colors = Array(EditorTextColor.allCases)

        withAnimation(.easeOut(duration: colorPickerSequenceDuration)) {
            colorPickerPanelProgress = 0
        }

        for (index, textColor) in colors.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + colorPickerDelay(for: index, count: colors.count)) {
                guard colorPickerAnimationID == animationID else { return }

                withAnimation(.easeOut(duration: colorPickerSwatchDuration)) {
                    _ = visibleColorPickerColors.remove(textColor)
                }
            }
        }

        let dismissDelay = colorPickerSequenceDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + dismissDelay) {
            guard colorPickerAnimationID == animationID else { return }

            isColorPickerPresented = false
            visibleColorPickerColors = []
        }
    }

    private func openColorPicker() {
        guard !isColorPickerPresented else { return }

        let animationID = UUID()
        colorPickerAnimationID = animationID
        colorPickerPanelProgress = 0
        visibleColorPickerColors = []

        isColorPickerPresented = true

        withAnimation(.easeOut(duration: colorPickerSequenceDuration)) {
            colorPickerPanelProgress = 1
        }

        for (index, textColor) in Array(EditorTextColor.allCases.reversed()).enumerated() {
            let delay = colorPickerOpeningSwatchDelay
                + colorPickerDelay(
                    for: index,
                    count: EditorTextColor.allCases.count,
                    duration: colorPickerSequenceDuration - colorPickerOpeningSwatchDelay
                )

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard colorPickerAnimationID == animationID, isColorPickerPresented else { return }

                withAnimation(.easeOut(duration: colorPickerSwatchDuration)) {
                    _ = visibleColorPickerColors.insert(textColor)
                }
            }
        }
    }

    private func colorPickerDelay(
        for index: Int,
        count: Int,
        duration: TimeInterval? = nil
    ) -> TimeInterval {
        guard count > 1 else { return 0 }
        let animationDuration = duration ?? colorPickerSequenceDuration
        let staggerWindow = max(animationDuration - colorPickerSwatchDuration, 0)
        return staggerWindow * Double(index) / Double(count - 1)
    }

    private func toggleColorPicker() {
        if isColorPickerPresented {
            closeColorPicker()
        } else {
            openColorPicker()
        }
    }

    private var colorPickerPanel: some View {
        ZStack(alignment: .trailing) {
            QMemoGlassBackground(
                shape: RoundedRectangle(cornerRadius: 22, style: .continuous),
                tintOpacity: 0.20,
                fallbackFillOpacity: 0.82,
                strokeOpacity: 0.62,
                lineOpacity: 0.10
            )
            .frame(width: colorPickerPanelWidth, height: colorPickerPanelHeight)
            .shadow(color: Theme.Colors.shadow.opacity(0.14), radius: 18, y: 8)

            colorPickerSwatches
                .frame(width: colorPickerPanelFullWidth, height: colorPickerPanelHeight, alignment: .trailing)
                .frame(width: colorPickerPanelWidth, height: colorPickerPanelHeight, alignment: .trailing)
                .clipped()
        }
        .frame(width: colorPickerPanelWidth, height: colorPickerPanelHeight, alignment: .trailing)
    }

    private var colorPickerSwatches: some View {
        HStack(spacing: 10) {
            ForEach(EditorTextColor.allCases, id: \.self) { textColor in
                Button {
                    onApplyTextColor(textColor)
                    closeColorPicker()
                } label: {
                    let isVisible = visibleColorPickerColors.contains(textColor)

                    Circle()
                        .fill(textColor.color)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 1)
                        )
                        .overlay(
                            Circle()
                                .stroke(
                                    activeTextColor == textColor ? selectedForeground : Color.clear,
                                    lineWidth: 2
                                )
                                .padding(-3)
                        )
                        .frame(width: 26, height: 26)
                        .frame(width: 38, height: 38)
                        .scaleEffect(isVisible ? 1 : 0.68)
                        .offset(x: isVisible ? 0 : 10)
                        .opacity(isVisible ? 1 : 0)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(textColor.accessibilityLabel)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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

    var blockStyle: EditorBlockStyle? {
        if case .block(let blockStyle) = kind {
            return blockStyle
        }

        return nil
    }

    func isCollapsedBlockStyleCommand(selectedRange: NSRange) -> Bool {
        guard selectedRange.length == 0 else { return false }

        return blockStyle != nil
    }

    func isCollapsedTypingOnlyCommand(selectedRange: NSRange) -> Bool {
        guard selectedRange.length == 0 else { return false }

        if case .textColor = kind {
            return true
        }

        return false
    }

    func usesExplicitTypingAttributes(selectedRange: NSRange) -> Bool {
        guard selectedRange.length == 0 else { return false }

        switch kind {
        case .block, .textColor:
            return true
        case .inline, .insertText:
            return false
        }
    }

    enum Kind: Equatable {
        case block(EditorBlockStyle)
        case inline(EditorInlineStyle, isActive: Bool)
        case textColor(EditorTextColor)
        case insertText(String)
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
    @Binding var richContentData: Data?
    @Binding var isFocused: Bool
    @Binding var flushedRequestID: UUID?
    @Binding var selectedBlockStyle: EditorBlockStyle
    @Binding var activeInlineStyles: Set<EditorInlineStyle>
    @Binding var activeTextColor: EditorTextColor?
    @Binding var pendingFormatCommand: EditorFormatCommand?

    let flushRequestID: UUID?
    let textColor: UIColor
    let lineSpacing: CGFloat
    let exclusionPaths: [UIBezierPath]

    private static let blockStyleAttribute = NSAttributedString.Key("QMemoBlockStyle")
    private static let inlineStylesAttribute = NSAttributedString.Key("QMemoInlineStyles")
    private static let lineHeightRatio: CGFloat = 1.25
    private static let monospaceInputHorizontalPadding: CGFloat = 8
    private static let monospaceInputVerticalPadding: CGFloat = 8
    private static let monospaceAdjacentTextGap: CGFloat = 4
    private static let monospaceBoundarySpacing = monospaceInputVerticalPadding + monospaceAdjacentTextGap
    private static let monospaceLineMergeGap: CGFloat = 9
    private static let monospaceInputCornerRadius: CGFloat = 8

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
        textView.typingAttributes = attributes(blockStyle: selectedBlockStyle, inlineStyles: activeInlineStyles, textColor: activeTextColor)
        textView.textContainer.exclusionPaths = boundedExclusionPaths(for: textView)
        textView.attributedText = storedAttributedString(for: text)
        textView.typingAttributes = attributes(blockStyle: selectedBlockStyle, inlineStyles: activeInlineStyles, textColor: activeTextColor)
        textView.onTapBelowText = { [weak textView, weak coordinator = context.coordinator] in
            guard let textView else { return }
            coordinator?.beginParagraphAfterContent(in: textView)
        }
        textView.refreshMonospaceBackgrounds()
        return textView
    }

    func updateUIView(_ textView: RichTextView, context: Context) {
        context.coordinator.parent = self
        textView.isScrollEnabled = false
        textView.textContainer.exclusionPaths = boundedExclusionPaths(for: textView)

        defer {
            updateHeight(for: textView)
            textView.refreshMonospaceBackgrounds()
        }

        if textView.text != text {
            let selectedRange = textView.selectedRange
            textView.attributedText = storedAttributedString(for: text)
            textView.selectedRange = clampedRange(selectedRange, in: text)
        }

        if let command = pendingFormatCommand,
           context.coordinator.appliedFormatCommandID != command.id {
            apply(command, to: textView, context: context)
            context.coordinator.appliedFormatCommandID = command.id
        } else {
            textView.typingAttributes = attributes(blockStyle: selectedBlockStyle, inlineStyles: activeInlineStyles, textColor: activeTextColor)
        }

        if let flushRequestID,
           context.coordinator.handledFlushRequestID != flushRequestID {
            context.coordinator.handledFlushRequestID = flushRequestID
            flushContent(from: textView, requestID: flushRequestID)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func apply(_ command: EditorFormatCommand, to textView: UITextView, context: Context) {
        let selectedRange = textView.selectedRange
        let mutableText = NSMutableAttributedString(attributedString: textView.attributedText ?? attributedString(for: textView.text))
        let nextAttributes = attributes(blockStyle: selectedBlockStyle, inlineStyles: activeInlineStyles, textColor: activeTextColor)

        if case .insertText(let insertedText) = command.kind {
            let insertionRange = clampedRange(selectedRange, in: textView.text)
            let attributedInsertedText = NSAttributedString(string: insertedText, attributes: nextAttributes)
            mutableText.replaceCharacters(in: insertionRange, with: attributedInsertedText)
            normalizeMonospaceParagraphSpacing(in: mutableText)
            textView.attributedText = mutableText
            textView.selectedRange = NSRange(location: insertionRange.location + insertedText.utf16.count, length: 0)
            text = mutableText.string
            richContentData = archivedData(for: mutableText)
            textView.typingAttributes = nextAttributes
            context.coordinator.explicitTypingLocation = nil
            context.coordinator.explicitTypingAttributes = nil
            updateHeight(for: textView)
            (textView as? RichTextView)?.refreshMonospaceBackgrounds()
            return
        }

        let targetRange = formatTargetRange(in: textView, command: command)

        if targetRange.length > 0 {
            apply(command, to: mutableText, in: clampedRange(targetRange, in: textView.text))
            normalizeMonospaceParagraphSpacing(in: mutableText)
            textView.attributedText = mutableText
            textView.selectedRange = clampedRange(selectedRange, in: textView.text)
            text = mutableText.string
            richContentData = archivedData(for: mutableText)
        }

        textView.typingAttributes = nextAttributes
        if command.usesExplicitTypingAttributes(selectedRange: selectedRange) {
            context.coordinator.explicitTypingLocation = selectedRange.location
            context.coordinator.explicitTypingAttributes = nextAttributes
        } else {
            context.coordinator.explicitTypingLocation = nil
            context.coordinator.explicitTypingAttributes = nil
        }
        updateHeight(for: textView)
        (textView as? RichTextView)?.refreshMonospaceBackgrounds()
    }

    private func apply(_ command: EditorFormatCommand, to text: NSMutableAttributedString, in range: NSRange) {
        guard range.length > 0 else { return }

        let runs = attributeRuns(in: text, range: range)

        for run in runs {
            var currentInlineStyles = run.inlineStyles
            var currentTextColor = run.textColor
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
            case .textColor(let textColor):
                nextBlockStyle = run.blockStyle
                currentTextColor = textColor
            case .insertText:
                nextBlockStyle = run.blockStyle
            }

            text.setAttributes(
                attributes(blockStyle: nextBlockStyle, inlineStyles: currentInlineStyles, textColor: currentTextColor),
                range: run.range
            )
        }
    }

    private func attributeRuns(
        in text: NSAttributedString,
        range targetRange: NSRange
    ) -> [(range: NSRange, blockStyle: EditorBlockStyle, inlineStyles: Set<EditorInlineStyle>, textColor: EditorTextColor?)] {
        var runs: [(NSRange, EditorBlockStyle, Set<EditorInlineStyle>, EditorTextColor?)] = []

        text.enumerateAttributes(in: targetRange, options: []) { attributes, effectiveRange, _ in
            let affectedRange = NSIntersectionRange(effectiveRange, targetRange)
            guard affectedRange.length > 0 else { return }

            runs.append((affectedRange, blockStyle(from: attributes), inlineStyles(from: attributes), textColor(from: attributes)))
        }

        return runs
    }

    private func formatTargetRange(in textView: UITextView, command: EditorFormatCommand) -> NSRange {
        let selectedRange = clampedRange(textView.selectedRange, in: textView.text)
        let nsText = textView.text as NSString
        let includesParagraphBoundary = command.isCollapsedBlockStyleCommand(selectedRange: selectedRange)

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

        if command.isCollapsedTypingOnlyCommand(selectedRange: selectedRange) {
            return NSRange(location: selectedRange.location, length: 0)
        }

        if includesParagraphBoundary,
           currentLineIsEmpty(in: nsText, at: selectedRange.location) {
            return emptyLineStyleRange(
                in: textView,
                text: nsText,
                at: selectedRange.location,
                applying: command.blockStyle
            )
        }

        if selectedRange.location == nsText.length,
           nsText.substring(from: max(nsText.length - 1, 0)) == "\n" {
            if includesParagraphBoundary {
                return NSRange(location: max(nsText.length - 1, 0), length: 1)
            }

            return NSRange(location: selectedRange.location, length: 0)
        }

        return visibleParagraphRange(
            in: nsText,
            at: min(selectedRange.location, nsText.length - 1),
            includesParagraphBoundary: includesParagraphBoundary
        )
    }

    private func visibleParagraphRange(
        in text: NSString,
        at location: Int,
        includesParagraphBoundary: Bool
    ) -> NSRange {
        let paragraphRange = text.paragraphRange(for: NSRange(location: location, length: 0))
        guard paragraphRange.length > 0 else { return paragraphRange }
        guard !includesParagraphBoundary else { return paragraphRange }

        let lastIndex = paragraphRange.location + paragraphRange.length - 1
        let includesTrailingNewline = text.substring(with: NSRange(location: lastIndex, length: 1)) == "\n"
        guard includesTrailingNewline else { return paragraphRange }

        return NSRange(
            location: paragraphRange.location,
            length: max(paragraphRange.length - 1, 0)
        )
    }

    private func currentLineIsEmpty(in text: NSString, at location: Int) -> Bool {
        guard text.length > 0 else { return true }

        if location == text.length,
           isNewline(in: text, at: location - 1) {
            return true
        }

        let paragraphRange = text.paragraphRange(
            for: NSRange(location: min(max(location, 0), text.length - 1), length: 0)
        )
        return visibleLength(in: text, range: paragraphRange) == 0
    }

    private func emptyLineStyleRange(
        in textView: UITextView,
        text: NSString,
        at location: Int,
        applying blockStyle: EditorBlockStyle?
    ) -> NSRange {
        if location == text.length,
           isNewline(in: text, at: location - 1) {
            if blockStyle != .monospace,
               characterBlockStyle(in: textView.attributedText, at: location - 1) == .monospace {
                return NSRange(location: location - 1, length: 1)
            }

            return NSRange(location: location, length: 0)
        }

        let paragraphRange = text.paragraphRange(
            for: NSRange(location: min(max(location, 0), text.length - 1), length: 0)
        )
        return visibleLength(in: text, range: paragraphRange) == 0
            ? paragraphRange
            : NSRange(location: location, length: 0)
    }

    private func characterBlockStyle(in attributedText: NSAttributedString?, at index: Int) -> EditorBlockStyle {
        guard let attributedText,
              index >= 0,
              index < attributedText.length
        else {
            return .body
        }

        return blockStyle(from: attributedText.attributes(at: index, effectiveRange: nil))
    }

    private func visibleLength(in text: NSString, range: NSRange) -> Int {
        guard range.length > 0 else { return 0 }

        var visibleLength = range.length
        var index = range.location + range.length - 1
        while visibleLength > 0, isNewline(in: text, at: index) {
            visibleLength -= 1
            index -= 1
        }

        return visibleLength
    }

    private func isNewline(in text: NSString, at index: Int) -> Bool {
        guard index >= 0, index < text.length else { return false }
        return text.substring(with: NSRange(location: index, length: 1)) == "\n"
    }

    private func attributes(
        blockStyle: EditorBlockStyle,
        inlineStyles: Set<EditorInlineStyle>,
        textColor selectedTextColor: EditorTextColor? = nil
    ) -> [NSAttributedString.Key: Any] {
        let font = font(blockStyle: blockStyle, inlineStyles: inlineStyles)
        let paragraphStyle = paragraphStyle(blockStyle: blockStyle, font: font)
        let foregroundColor = selectedTextColor?.uiColor ?? textColor

        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: foregroundColor,
            .paragraphStyle: paragraphStyle,
            .baselineOffset: Self.baselineOffset(for: font),
            Self.blockStyleAttribute: blockStyle.rawValue,
            Self.inlineStylesAttribute: inlineStyles.map(\.rawValue).sorted().joined(separator: ",")
        ]

        if let selectedTextColor {
            attributes[.backgroundColor] = selectedTextColor.backgroundUIColor
        }

        if inlineStyles.contains(.underline) {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }

        if inlineStyles.contains(.strikethrough) {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }

        return attributes
    }

    private func paragraphStyle(blockStyle: EditorBlockStyle, font: UIFont) -> NSMutableParagraphStyle {
        let lineHeight = Self.lineHeight(for: font)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = lineHeight
        paragraphStyle.maximumLineHeight = lineHeight
        paragraphStyle.lineSpacing = 0
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.paragraphSpacing = 0
        if blockStyle == .monospace {
            paragraphStyle.firstLineHeadIndent = Self.monospaceInputHorizontalPadding
            paragraphStyle.headIndent = Self.monospaceInputHorizontalPadding
            paragraphStyle.tailIndent = -Self.monospaceInputHorizontalPadding
        }

        return paragraphStyle
    }

    private func normalizeMonospaceParagraphSpacing(in attributedText: NSMutableAttributedString) {
        let text = attributedText.string as NSString
        guard text.length > 0 else { return }

        let paragraphs = paragraphDescriptors(in: attributedText, text: text)
        for (index, paragraph) in paragraphs.enumerated() where paragraph.blockStyle == .monospace {
            let previousBlockStyle = index > 0 ? paragraphs[index - 1].blockStyle : nil
            let nextBlockStyle = index < paragraphs.count - 1 ? paragraphs[index + 1].blockStyle : nil
            let attributes = attributedText.attributes(at: paragraph.attributeIndex, effectiveRange: nil)
            let inlineStyles = inlineStyles(from: attributes)
            let font = attributes[.font] as? UIFont ?? font(blockStyle: paragraph.blockStyle, inlineStyles: inlineStyles)
            let paragraphStyle = paragraphStyle(blockStyle: paragraph.blockStyle, font: font)

            if let previousBlockStyle, previousBlockStyle != .monospace {
                paragraphStyle.paragraphSpacingBefore = Self.monospaceBoundarySpacing
            }

            if let nextBlockStyle, nextBlockStyle != .monospace {
                paragraphStyle.paragraphSpacing = Self.monospaceBoundarySpacing
            }

            attributedText.addAttribute(.paragraphStyle, value: paragraphStyle, range: paragraph.range)
        }
    }

    private func normalizedAttributedString(_ attributedText: NSAttributedString) -> NSAttributedString {
        let mutableText = NSMutableAttributedString(attributedString: attributedText)
        normalizeMonospaceParagraphSpacing(in: mutableText)
        return mutableText
    }

    private func paragraphDescriptors(
        in attributedText: NSAttributedString,
        text: NSString
    ) -> [(range: NSRange, attributeIndex: Int, blockStyle: EditorBlockStyle)] {
        var descriptors: [(NSRange, Int, EditorBlockStyle)] = []
        var location = 0

        while location < text.length {
            let paragraphRange = text.paragraphRange(for: NSRange(location: location, length: 0))
            let attributeIndex = paragraphAttributeIndex(in: text, paragraphRange: paragraphRange)
            let blockStyle = blockStyle(from: attributedText.attributes(at: attributeIndex, effectiveRange: nil))
            descriptors.append((paragraphRange, attributeIndex, blockStyle))

            let nextLocation = NSMaxRange(paragraphRange)
            guard nextLocation > location else { break }
            location = nextLocation
        }

        return descriptors
    }

    private func paragraphAttributeIndex(in text: NSString, paragraphRange: NSRange) -> Int {
        let end = NSMaxRange(paragraphRange)
        var index = paragraphRange.location

        while index < end {
            if !isNewline(in: text, at: index) {
                return index
            }
            index += 1
        }

        return min(max(paragraphRange.location, 0), max(text.length - 1, 0))
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

    private func storedAttributedString(for text: String) -> NSAttributedString {
        guard let richContentData,
              let storedString = try? NSKeyedUnarchiver.unarchivedObject(
                ofClass: NSAttributedString.self,
                from: richContentData
              )
        else {
            return attributedString(for: text)
        }

        if storedString.string == text
            || storedString.string.trimmingCharacters(in: .whitespacesAndNewlines) == text {
            return normalizedAttributedString(storedString)
        } else {
            return attributedString(for: text)
        }
    }

    private func archivedData(for attributedText: NSAttributedString?) -> Data? {
        guard let attributedText else { return nil }

        return try? NSKeyedArchiver.archivedData(
            withRootObject: attributedText,
            requiringSecureCoding: true
        )
    }

    private func syncContent(from textView: UITextView) {
        normalizeMonospaceParagraphSpacing(in: textView.textStorage)
        text = textView.text ?? ""
        richContentData = archivedData(for: textView.attributedText)
    }

    private func flushContent(from textView: UITextView, requestID: UUID) {
        normalizeMonospaceParagraphSpacing(in: textView.textStorage)
        let currentText = textView.text ?? ""
        let currentRichContentData = archivedData(for: textView.attributedText)

        DispatchQueue.main.async {
            text = currentText
            richContentData = currentRichContentData
            flushedRequestID = requestID
        }
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

    private func textColor(from attributes: [NSAttributedString.Key: Any]) -> EditorTextColor? {
        guard let foregroundColor = attributes[.foregroundColor] as? UIColor else { return nil }

        return EditorTextColor.allCases.first { $0.matches(foregroundColor) }
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
        private let monospaceBackgroundLayer = CAShapeLayer()
        var onTapBelowText: (() -> Void)?

        override init(frame: CGRect, textContainer: NSTextContainer?) {
            super.init(frame: frame, textContainer: textContainer)
            configureMonospaceBackgroundLayer()
            configureBlankAreaTapRecognizer()
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            configureMonospaceBackgroundLayer()
            configureBlankAreaTapRecognizer()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            refreshMonospaceBackgrounds()
        }

        override var keyCommands: [UIKeyCommand]? {
            guard isCurrentCaretMonospace else {
                return super.keyCommands
            }

            var commands = super.keyCommands ?? []
            commands.append(Self.monospaceArrowCommand(input: UIKeyCommand.inputUpArrow))
            commands.append(Self.monospaceArrowCommand(input: UIKeyCommand.inputDownArrow))
            return commands
        }

        private static func monospaceArrowCommand(input: String) -> UIKeyCommand {
            let command = UIKeyCommand(
                input: input,
                modifierFlags: [],
                action: #selector(ignoreMonospaceVerticalArrowKey(_:))
            )
            command.wantsPriorityOverSystemBehavior = true
            return command
        }

        @objc private func ignoreMonospaceVerticalArrowKey(_ sender: UIKeyCommand) {
            refreshMonospaceBackgrounds()
        }

        private func configureMonospaceBackgroundLayer() {
            monospaceBackgroundLayer.fillColor = UIColor(
                red: 0x49 / 255,
                green: 0x39 / 255,
                blue: 0x2F / 255,
                alpha: 0.08
            ).cgColor
            monospaceBackgroundLayer.actions = [
                "path": NSNull(),
                "position": NSNull(),
                "bounds": NSNull()
            ]
            layer.insertSublayer(monospaceBackgroundLayer, at: 0)
        }

        private func configureBlankAreaTapRecognizer() {
            let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleBlankAreaTap(_:)))
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            addGestureRecognizer(recognizer)
        }

        @objc private func handleBlankAreaTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended,
                  isTapBelowRenderedText(recognizer.location(in: self))
            else {
                return
            }

            onTapBelowText?()
        }

        private func isTapBelowRenderedText(_ location: CGPoint) -> Bool {
            guard textStorage.length > 0,
                  let endPosition = position(
                    from: beginningOfDocument,
                    offset: textStorage.length
                  )
            else {
                return false
            }

            let endCaretRect = super.caretRect(for: endPosition)
            return location.y > endCaretRect.maxY + 2
        }

        func refreshMonospaceBackgrounds() {
            layoutManager.ensureLayout(for: textContainer)
            monospaceBackgroundLayer.frame = bounds

            let path = UIBezierPath()
            monospaceParagraphRects().forEach { rect in
                path.append(
                    UIBezierPath(
                        roundedRect: rect,
                        cornerRadius: MemoBodyTextView.monospaceInputCornerRadius
                    )
                )
            }

            monospaceBackgroundLayer.path = path.cgPath
        }

        private func monospaceParagraphRects() -> [CGRect] {
            var lineRects = monospaceLineRects()

            if isTypingMonospace,
               let activeBlockRect = activeMonospaceBlockRect(),
               !lineRects.contains(where: { $0.contains(activeBlockRect) }) {
                lineRects.append(activeBlockRect)
            }

            return mergedLineRects(lineRects).map(paddedInputRect(from:))
        }

        private var isTypingMonospace: Bool {
            typingAttributes[MemoBodyTextView.blockStyleAttribute] as? String == EditorBlockStyle.monospace.rawValue
        }

        private var isCurrentCaretMonospace: Bool {
            guard let selectedPosition = selectedTextRange?.start else { return false }
            return isActiveMonospaceCaret(at: selectedPosition)
        }

        private func monospaceLineRects() -> [CGRect] {
            let storageLength = textStorage.length
            guard storageLength > 0 else { return [] }

            let fullCharacterRange = NSRange(location: 0, length: storageLength)
            layoutManager.ensureLayout(forCharacterRange: fullCharacterRange)

            var lineRects: [CGRect] = []
            let glyphRange = layoutManager.glyphRange(
                forCharacterRange: fullCharacterRange,
                actualCharacterRange: nil
            )
            layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { lineRect, _, _, glyphRange, _ in
                let characterRange = self.layoutManager.characterRange(
                    forGlyphRange: glyphRange,
                    actualGlyphRange: nil
                )

                guard self.isMonospaceLine(characterRange: characterRange) else { return }
                lineRects.append(lineRect)
            }

            return lineRects
        }

        private func activeMonospaceBlockRect() -> CGRect? {
            guard isTypingMonospace,
                  let selectedPosition = selectedTextRange?.start,
                  let textRange = textRange(from: beginningOfDocument, to: selectedPosition)
            else {
                return nil
            }

            let caretCharacterIndex = offset(from: beginningOfDocument, to: textRange.end)
            let nsText = textStorage.string as NSString
            guard caretCharacterIndex <= nsText.length else { return nil }

            return monospaceBlockRect(
                endingAt: caretCharacterIndex,
                in: nsText,
                activeLineRect: activeMonospaceLineRect()
            )
        }

        private func monospaceBlockRect(
            endingAt location: Int,
            in nsText: NSString,
            activeLineRect: CGRect?
        ) -> CGRect? {
            let blockRange = activeMonospaceBlockRange(endingAt: location, in: nsText)
            let lineCount = max(
                monospaceBlockLineCount(
                    in: nsText,
                    range: blockRange,
                    includesTrailingInsertionLine: activeLineRect != nil
                        && blockRange.length > 0
                        && isNewline(at: NSMaxRange(blockRange) - 1, in: nsText)
                ),
                1
            )
            let firstLineRect = firstMonospaceLineRect(in: blockRange, text: nsText) ?? activeLineRect
            guard let firstLineRect else { return nil }

            let fallbackFont = typingAttributes[.font] as? UIFont
                ?? UIFont.monospacedSystemFont(
                    ofSize: EditorBlockStyle.monospace.bodyFontSize,
                    weight: EditorBlockStyle.monospace.bodyFontWeight
            )
            let fallbackLineHeight = MemoBodyTextView.lineHeight(for: fallbackFont)
            let lineHeight = max(firstLineRect.height, activeLineRect?.height ?? 0, fallbackLineHeight)

            return CGRect(
                x: firstLineRect.minX,
                y: firstLineRect.minY,
                width: max(firstLineRect.width, activeLineRect?.width ?? 0, textContainer.size.width),
                height: max(CGFloat(lineCount) * lineHeight, lineHeight)
            )
        }

        private func firstMonospaceLineRect(in blockRange: NSRange, text: NSString) -> CGRect? {
            guard blockRange.length > 0 else { return nil }

            let storageLength = textStorage.length
            guard storageLength > 0 else { return nil }

            if isNewline(at: blockRange.location, in: text),
               let leadingEmptyLineRect = lineRectForInsertionPoint(afterCharacterAt: blockRange.location) {
                return leadingEmptyLineRect
            }

            let characterIndex = min(max(blockRange.location, 0), storageLength - 1)
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: characterIndex)
            return layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
        }

        private func lineRectForInsertionPoint(afterCharacterAt characterIndex: Int) -> CGRect? {
            guard let position = position(
                from: beginningOfDocument,
                offset: min(max(characterIndex + 1, 0), textStorage.length)
            ) else {
                return nil
            }

            return textContainerRect(from: super.caretRect(for: position))
        }

        private func monospaceBlockLineCount(
            in text: NSString,
            range: NSRange,
            includesTrailingInsertionLine: Bool = false
        ) -> Int {
            guard range.length > 0 else { return 1 }

            var newlineCount = 0
            let end = NSMaxRange(range)
            var index = range.location
            while index < end {
                if text.substring(with: NSRange(location: index, length: 1)) == "\n" {
                    newlineCount += 1
                }
                index += 1
            }

            let endsWithNewline = isNewline(at: end - 1, in: text)
            let representedLineCount = newlineCount + (endsWithNewline ? 0 : 1)
            return max(representedLineCount + (includesTrailingInsertionLine ? 1 : 0), 1)
        }

        private func activeMonospaceBlockRange(endingAt location: Int, in text: NSString) -> NSRange {
            let storageLength = textStorage.length
            guard storageLength > 0 else { return NSRange(location: 0, length: 0) }

            let blockEnd = min(max(location, 0), storageLength)
            var contentEnd = blockEnd
            var hasStyledTrailingNewline = false

            while contentEnd > 0, isNewline(at: contentEnd - 1, in: text) {
                if isMonospaceCharacter(at: contentEnd - 1) {
                    hasStyledTrailingNewline = true
                }
                contentEnd -= 1
            }

            var contentStart = contentEnd
            while contentStart > 0, isMonospaceCharacter(at: contentStart - 1) {
                contentStart -= 1
            }

            if contentStart < contentEnd {
                return NSRange(
                    location: contentStart,
                    length: max(blockEnd - contentStart, 0)
                )
            }

            if hasStyledTrailingNewline {
                return NSRange(
                    location: contentEnd,
                    length: max(blockEnd - contentEnd, 0)
                )
            }

            return NSRange(
                location: blockEnd,
                length: 0
            )
        }

        private func isMonospaceCharacter(at index: Int) -> Bool {
            guard index >= 0, index < textStorage.length else { return false }
            return textStorage.attribute(
                MemoBodyTextView.blockStyleAttribute,
                at: index,
                effectiveRange: nil
            ) as? String == EditorBlockStyle.monospace.rawValue
        }

        private func isNewline(at index: Int, in text: NSString) -> Bool {
            guard index >= 0, index < text.length else { return false }
            return text.substring(with: NSRange(location: index, length: 1)) == "\n"
        }

        private func isMonospaceLine(characterRange: NSRange) -> Bool {
            let storageLength = textStorage.length
            guard storageLength > 0 else { return false }
            let nsText = textStorage.string as NSString

            guard let inspectIndex = lineStyleIndex(in: characterRange, text: nsText) else {
                return false
            }

            return isMonospaceCharacter(at: inspectIndex)
        }

        private func lineStyleIndex(in characterRange: NSRange, text: NSString) -> Int? {
            let storageLength = textStorage.length
            let start = min(max(characterRange.location, 0), storageLength)
            let end = min(max(NSMaxRange(characterRange), start), storageLength)

            if start < end {
                var newlineIndex: Int?

                for index in start..<end {
                    if isNewline(at: index, in: text) {
                        if newlineIndex == nil {
                            newlineIndex = index
                        }
                    } else {
                        return index
                    }
                }

                return newlineIndex
            }

            guard start < storageLength else { return nil }
            return start
        }

        private func mergedLineRects(_ lineRects: [CGRect]) -> [CGRect] {
            let sortedRects = lineRects.sorted {
                if abs($0.minY - $1.minY) > 0.5 {
                    return $0.minY < $1.minY
                }

                return $0.minX < $1.minX
            }

            return sortedRects.reduce(into: []) { mergedRects, rect in
                guard let lastRect = mergedRects.last else {
                    mergedRects.append(rect)
                    return
                }

                let maxMergeGap = MemoBodyTextView.monospaceLineMergeGap
                if rect.minY <= lastRect.maxY + maxMergeGap {
                    mergedRects[mergedRects.count - 1] = lastRect.union(rect)
                } else {
                    mergedRects.append(rect)
                }
            }
        }

        private func activeMonospaceLineRect() -> CGRect? {
            guard let selectedPosition = selectedTextRange?.start else { return nil }

            var rect = lineRect(for: selectedPosition) ?? textContainerRect(from: super.caretRect(for: selectedPosition))
            if rect.height <= 0,
               let activeFont = typingAttributes[.font] as? UIFont {
                rect.size.height = MemoBodyTextView.lineHeight(for: activeFont)
            }

            guard rect.height > 0 else { return nil }
            return rect
        }

        private func textContainerRect(from rect: CGRect) -> CGRect {
            rect.offsetBy(dx: -textContainerInset.left, dy: -textContainerInset.top)
        }

        private func paddedInputRect(from sourceRect: CGRect) -> CGRect {
            let verticalPadding = MemoBodyTextView.monospaceInputVerticalPadding
            let containerWidth = textContainer.size.width > 0 ? textContainer.size.width : bounds.width
            var minY = max(0, textContainerInset.top + sourceRect.minY - verticalPadding)
            var maxY = textContainerInset.top + sourceRect.maxY + verticalPadding

            if let previousTextLineRect = nearestNonMonospaceLineRect(above: sourceRect) {
                minY = max(
                    minY,
                    textContainerInset.top + previousTextLineRect.maxY + MemoBodyTextView.monospaceAdjacentTextGap
                )
            }

            if let nextTextLineRect = nearestNonMonospaceLineRect(below: sourceRect) {
                maxY = min(
                    maxY,
                    textContainerInset.top + nextTextLineRect.minY - MemoBodyTextView.monospaceAdjacentTextGap
                )
            }

            return CGRect(
                x: textContainerInset.left,
                y: minY,
                width: max(containerWidth, 1),
                height: max(maxY - minY, 1)
            )
        }

        private func nearestNonMonospaceLineRect(above sourceRect: CGRect) -> CGRect? {
            nonMonospaceLineRects()
                .filter { $0.maxY <= sourceRect.minY + 0.5 }
                .max { $0.maxY < $1.maxY }
        }

        private func nearestNonMonospaceLineRect(below sourceRect: CGRect) -> CGRect? {
            nonMonospaceLineRects()
                .filter { $0.minY >= sourceRect.maxY - 0.5 }
                .min { $0.minY < $1.minY }
        }

        private func nonMonospaceLineRects() -> [CGRect] {
            let storageLength = textStorage.length
            guard storageLength > 0 else { return [] }

            let fullCharacterRange = NSRange(location: 0, length: storageLength)
            layoutManager.ensureLayout(forCharacterRange: fullCharacterRange)

            var lineRects: [CGRect] = []
            let glyphRange = layoutManager.glyphRange(
                forCharacterRange: fullCharacterRange,
                actualCharacterRange: nil
            )
            layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { lineRect, _, _, glyphRange, _ in
                let characterRange = self.layoutManager.characterRange(
                    forGlyphRange: glyphRange,
                    actualGlyphRange: nil
                )

                guard !self.isMonospaceLine(characterRange: characterRange) else { return }
                lineRects.append(lineRect)
            }

            return lineRects
        }

        override func caretRect(for position: UITextPosition) -> CGRect {
            var rect = super.caretRect(for: position)
            let isMonospaceCaret = isActiveMonospaceCaret(at: position)
            let activeFont = typingAttributes[.font] as? UIFont
                ?? font
                ?? UIFont.systemFont(ofSize: EditorBlockStyle.body.bodyFontSize)
            let caretHeight = isMonospaceCaret
                ? UIFont.systemFont(
                    ofSize: EditorBlockStyle.body.bodyFontSize,
                    weight: EditorBlockStyle.body.bodyFontWeight
                ).lineHeight
                : activeFont.lineHeight

            let alignmentRect = isMonospaceCaret
                ? monospaceCaretAlignmentRect(for: position)
                : lineRect(for: position)

            if let lineRect = alignmentRect {
                rect.origin.y = textContainerInset.top + lineRect.midY - caretHeight / 2
            } else {
                rect.origin.y = rect.midY - caretHeight / 2
            }

            rect.size.height = caretHeight
            return rect
        }

        private func monospaceCaretAlignmentRect(for position: UITextPosition) -> CGRect? {
            guard let textRange = textRange(from: beginningOfDocument, to: position) else {
                return nil
            }

            let characterIndex = offset(from: beginningOfDocument, to: textRange.end)
            let storageLength = textStorage.length
            guard storageLength > 0 else { return nil }

            layoutManager.ensureLayout(for: textContainer)

            if characterIndex == storageLength,
               textStorage.string.hasSuffix("\n") {
                return trailingMonospaceCaretLineRect(endingAt: characterIndex)
            }

            let boundedCharacterIndex = min(max(characterIndex, 0), storageLength - 1)
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: boundedCharacterIndex)
            let usedRect = layoutManager.lineFragmentUsedRect(forGlyphAt: glyphIndex, effectiveRange: nil)

            guard usedRect.height > 0 else {
                return layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            }

            return usedRect
        }

        private func lineRect(for position: UITextPosition) -> CGRect? {
            guard let textRange = textRange(from: beginningOfDocument, to: position) else {
                return nil
            }

            let characterIndex = offset(from: beginningOfDocument, to: textRange.end)
            let storageLength = textStorage.length
            guard storageLength > 0 else { return nil }

            layoutManager.ensureLayout(for: textContainer)

            if characterIndex == storageLength,
               textStorage.string.hasSuffix("\n") {
                if isActiveMonospaceCaret(at: position) {
                    return trailingMonospaceCaretLineRect(endingAt: characterIndex)
                }

                var rect = textContainerRect(from: super.caretRect(for: position))
                if isEmptyTrailingParagraphAfterMonospace(endingAt: characterIndex) {
                    rect.origin.y += MemoBodyTextView.monospaceBoundarySpacing
                }
                return rect
            }

            let boundedCharacterIndex = min(max(characterIndex, 0), storageLength - 1)
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: boundedCharacterIndex)
            return layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
        }

        private func isEmptyTrailingParagraphAfterMonospace(endingAt location: Int) -> Bool {
            let newlineIndex = location - 1
            let previousCharacterIndex = newlineIndex - 1
            guard newlineIndex >= 0,
                  previousCharacterIndex >= 0,
                  newlineIndex < textStorage.length,
                  textStorage.string.hasSuffix("\n")
            else {
                return false
            }

            return !isMonospaceCharacter(at: newlineIndex)
                && isMonospaceCharacter(at: previousCharacterIndex)
        }

        private func trailingMonospaceCaretLineRect(endingAt location: Int) -> CGRect? {
            let nsText = textStorage.string as NSString
            let blockRange = activeMonospaceBlockRange(endingAt: location, in: nsText)
            guard blockRange.length > 0,
                  let firstLineRect = firstMonospaceLineRect(in: blockRange, text: nsText)
            else {
                return nil
            }

            let fallbackFont = typingAttributes[.font] as? UIFont
                ?? UIFont.monospacedSystemFont(
                    ofSize: EditorBlockStyle.monospace.bodyFontSize,
                    weight: EditorBlockStyle.monospace.bodyFontWeight
                )
            let lineHeight = max(firstLineRect.height, MemoBodyTextView.lineHeight(for: fallbackFont))
            let lineIndex = max(
                monospaceBlockLineCount(
                    in: nsText,
                    range: blockRange,
                    includesTrailingInsertionLine: true
                ) - 1,
                0
            )

            return CGRect(
                x: firstLineRect.minX,
                y: firstLineRect.minY + CGFloat(lineIndex) * lineHeight,
                width: max(firstLineRect.width, textContainer.size.width),
                height: lineHeight
            )
        }

        private func isActiveMonospaceCaret(at position: UITextPosition) -> Bool {
            if let typingBlockStyle = typingAttributes[MemoBodyTextView.blockStyleAttribute] as? String {
                return typingBlockStyle == EditorBlockStyle.monospace.rawValue
            }

            if typingAttributes[.font] != nil {
                return false
            }

            if typingAttributes[MemoBodyTextView.blockStyleAttribute] as? String == EditorBlockStyle.monospace.rawValue {
                return true
            }

            guard let textRange = textRange(from: beginningOfDocument, to: position) else {
                return false
            }

            let characterIndex = offset(from: beginningOfDocument, to: textRange.end)
            let storageLength = textStorage.length
            guard storageLength > 0 else { return false }

            let inspectIndex = min(max(characterIndex - (characterIndex == storageLength ? 1 : 0), 0), storageLength - 1)
            return textStorage.attribute(
                MemoBodyTextView.blockStyleAttribute,
                at: inspectIndex,
                effectiveRange: nil
            ) as? String == EditorBlockStyle.monospace.rawValue
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: MemoBodyTextView
        var appliedFormatCommandID: UUID?
        var handledFlushRequestID: UUID?
        var explicitTypingLocation: Int?
        var explicitTypingAttributes: [NSAttributedString.Key: Any]?

        init(_ parent: MemoBodyTextView) {
            self.parent = parent
        }

        func beginParagraphAfterContent(in textView: RichTextView) {
            let textLength = textView.textStorage.length
            guard textLength > 0 else {
                DispatchQueue.main.async {
                    textView.becomeFirstResponder()
                    textView.selectedRange = NSRange(location: 0, length: 0)
                }
                return
            }

            let trailingAttributes = textView.textStorage.attributes(
                at: textLength - 1,
                effectiveRange: nil
            )
            let trailingBlockStyle = parent.blockStyle(from: trailingAttributes)
            let shouldExitMonospace = trailingBlockStyle == .monospace
            let nextParagraphAttributes = shouldExitMonospace
                ? parent.attributes(
                    blockStyle: .body,
                    inlineStyles: parent.inlineStyles(from: trailingAttributes),
                    textColor: parent.textColor(from: trailingAttributes)
                )
                : trailingAttributes

            let trailingCharacterRange = NSRange(location: textLength - 1, length: 1)
            let endsWithNewline = (textView.text as NSString).substring(
                with: trailingCharacterRange
            ) == "\n"

            if !endsWithNewline {
                textView.textStorage.append(
                    NSAttributedString(
                        string: "\n",
                        attributes: shouldExitMonospace ? nextParagraphAttributes : trailingAttributes
                    )
                )
                textView.typingAttributes = nextParagraphAttributes
                parent.syncContent(from: textView)
                parent.updateHeight(for: textView)
                textView.refreshMonospaceBackgrounds()
            } else if shouldExitMonospace {
                textView.textStorage.setAttributes(
                    nextParagraphAttributes,
                    range: trailingCharacterRange
                )
                textView.typingAttributes = nextParagraphAttributes
                parent.syncContent(from: textView)
                parent.updateHeight(for: textView)
                textView.refreshMonospaceBackgrounds()
            }

            DispatchQueue.main.async { [weak self, weak textView] in
                guard let self, let textView else { return }
                textView.becomeFirstResponder()
                textView.selectedRange = NSRange(location: textView.textStorage.length, length: 0)
                textView.typingAttributes = nextParagraphAttributes
                explicitTypingLocation = shouldExitMonospace ? textView.textStorage.length : nil
                explicitTypingAttributes = shouldExitMonospace ? nextParagraphAttributes : nil
                syncSelectionStyle(from: textView)
            }
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard text.contains("\n"),
                  let monospaceAttributes = monospaceAttributesForInsertion(in: textView, range: range)
            else {
                return true
            }

            textView.typingAttributes = monospaceAttributes
            return true
        }

        private func monospaceAttributesForInsertion(
            in textView: UITextView,
            range: NSRange
        ) -> [NSAttributedString.Key: Any]? {
            if let explicitTypingLocation,
               explicitTypingLocation == range.location,
               let explicitTypingAttributes,
               explicitTypingAttributes[MemoBodyTextView.blockStyleAttribute] as? String != EditorBlockStyle.monospace.rawValue {
                return nil
            }

            if textView.typingAttributes[MemoBodyTextView.blockStyleAttribute] as? String == EditorBlockStyle.monospace.rawValue {
                return textView.typingAttributes
            }

            let storageLength = textView.textStorage.length
            guard storageLength > 0 else { return nil }

            if range.location > 0 {
                let attributes = textView.textStorage.attributes(
                    at: min(range.location - 1, storageLength - 1),
                    effectiveRange: nil
                )
                return attributes[MemoBodyTextView.blockStyleAttribute] as? String == EditorBlockStyle.monospace.rawValue
                    ? attributes
                    : nil
            }

            if range.location < storageLength {
                let attributes = textView.textStorage.attributes(at: range.location, effectiveRange: nil)
                return attributes[MemoBodyTextView.blockStyleAttribute] as? String == EditorBlockStyle.monospace.rawValue
                    ? attributes
                    : nil
            }

            return nil
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.isFocused = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.syncContent(from: textView)
            parent.updateHeight(for: textView)
            parent.isFocused = false
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.syncContent(from: textView)
            parent.updateHeight(for: textView)
            (textView as? RichTextView)?.refreshMonospaceBackgrounds()
            explicitTypingLocation = nil
            explicitTypingAttributes = nil
            syncSelectionStyle(from: textView)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            syncSelectionStyle(from: textView)
            (textView as? RichTextView)?.refreshMonospaceBackgrounds()
        }

        func syncSelectionStyle(from textView: UITextView) {
            guard let attributedText = textView.attributedText,
                  attributedText.length > 0
            else {
                parent.selectedBlockStyle = .body
                parent.activeInlineStyles = []
                parent.activeTextColor = nil
                textView.typingAttributes = parent.attributes(blockStyle: .body, inlineStyles: [])
                return
            }

            let attributes = selectionAttributes(from: textView, attributedText: attributedText)
            let blockStyle = parent.blockStyle(from: attributes)
            let inlineStyles = parent.inlineStyles(from: attributes)
            let textColor = parent.textColor(from: attributes)

            if parent.selectedBlockStyle != blockStyle {
                parent.selectedBlockStyle = blockStyle
            }

            if parent.activeInlineStyles != inlineStyles {
                parent.activeInlineStyles = inlineStyles
            }

            if parent.activeTextColor != textColor {
                parent.activeTextColor = textColor
            }

            textView.typingAttributes = parent.attributes(blockStyle: blockStyle, inlineStyles: inlineStyles, textColor: textColor)
        }

        private func selectionAttributes(
            from textView: UITextView,
            attributedText: NSAttributedString
        ) -> [NSAttributedString.Key: Any] {
            let selectedRange = textView.selectedRange
            let length = attributedText.length
            let fallbackIndex = min(max(selectedRange.location - (selectedRange.location == length ? 1 : 0), 0), length - 1)

            guard selectedRange.length == 0 else {
                return attributedText.attributes(at: fallbackIndex, effectiveRange: nil)
            }

            if let explicitTypingLocation,
               explicitTypingLocation == selectedRange.location,
               let explicitTypingAttributes {
                return explicitTypingAttributes
            }

            if selectedRange.location < length,
               shouldReadCurrentCharacterAttributes(
                in: attributedText.string as NSString,
                at: selectedRange.location
               ) {
                return attributedText.attributes(at: selectedRange.location, effectiveRange: nil)
            }

            if selectedRange.location > 0 {
                return attributedText.attributes(
                    at: min(selectedRange.location - 1, length - 1),
                    effectiveRange: nil
                )
            }

            return attributedText.attributes(at: min(selectedRange.location, length - 1), effectiveRange: nil)
        }

        private func shouldReadCurrentCharacterAttributes(in text: NSString, at location: Int) -> Bool {
            guard location >= 0, location < text.length else { return false }
            guard location > 0 else { return true }

            return isNewline(in: text, at: location - 1)
        }

        private func isNewline(in text: NSString, at index: Int) -> Bool {
            guard index >= 0, index < text.length else { return false }
            return text.substring(with: NSRange(location: index, length: 1)) == "\n"
        }

    }
}

extension MemoBodyTextView.RichTextView: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}

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
    @State private var isStickerPickerPresented = false
    @State private var placedStickers: [PlacedEditorSticker] = []
    @State private var selectedStickerID: UUID?
    @State private var stickerDeletePromptID: UUID?
    private let editorLineSpacing: CGFloat = 32
    private let editorBodyLineSpacing: CGFloat = 8
    private var canUndoInput: Bool {
        !undoStack.isEmpty
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
    private var stickerExclusionRects: [CGRect] {
        placedStickers.map(\.textExclusionRect)
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

                    MemoBodyTextView(
                        text: $content,
                        calculatedHeight: $bodyTextHeight,
                        font: .systemFont(ofSize: 17, weight: .semibold),
                        textColor: UIColor(Theme.Colors.text),
                        lineSpacing: editorBodyLineSpacing,
                        exclusionRects: stickerExclusionRects
                    )
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
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    undoLastInput()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .accessibilityLabel("撤回")
                .disabled(!canUndoInput)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    save()
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

                Button {
                    undoLastInput()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(canUndoInput ? Theme.Colors.text : Theme.Colors.muted.opacity(0.42))
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
                .disabled(!canUndoInput)

                Button {
                    save()
                } label: {
                    Text("保存")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(
                            title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Theme.Colors.muted.opacity(0.42)
                                : Theme.Colors.text
                        )
                        .frame(width: 56, height: 44)
                        .background(
                            QMemoGlassBackground(
                                shape: Capsule(),
                                tintOpacity: 0.20,
                                fallbackFillOpacity: 0.84,
                                strokeOpacity: 0.70,
                                lineOpacity: 0.10
                            )
                        )
                        .shadow(color: Theme.Colors.shadow.opacity(0.10), radius: 10, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)

            Spacer()
        }
        .opacity(isCustomNavigationVisible ? 1 : 0)
        .offset(y: isCustomNavigationVisible ? 0 : -34)
        .allowsHitTesting(isCustomNavigationVisible)
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
        }
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
                withAnimation(.easeOut(duration: 0.18)) {
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
                            withAnimation(.easeOut(duration: 0.18)) {
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
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private var functionPanel: some View {
        HStack(spacing: 10) {
            Image(category.iconAsset)
                .resizable()
                .frame(width: 30, height: 30)
            Text(category.title)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Theme.Colors.text)

            Button {
                withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.24)) {
                    isStickerPickerPresented = true
                }
            } label: {
                Image(systemName: "face.smiling")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Theme.Colors.text)
                    .frame(width: 40, height: 40)
                    .background(Theme.Colors.surfaceStrong.opacity(0.52))
                    .clipShape(Circle())
            }
            .accessibilityLabel("贴纸")
            .buttonStyle(.plain)

            Spacer()
            Text("置顶")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.Colors.text)
            Toggle("置顶", isOn: $isPinned)
                .labelsHidden()
        }
        .padding(.horizontal, 18)
        .frame(height: 64)
        .background(
            QMemoGlassBackground(
                shape: RoundedRectangle(cornerRadius: 22, style: .continuous),
                tintOpacity: 0.20,
                fallbackFillOpacity: 0.78,
                strokeOpacity: 0.66,
                lineOpacity: 0.12
            )
        )
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanContent = content.trimmingCharacters(in: .whitespacesAndNewlines)

        if let memo {
            store.update(memo, title: cleanTitle, content: cleanContent, isPinned: isPinned)
        } else {
            store.create(title: cleanTitle, content: cleanContent, category: category, isPinned: isPinned)
        }

        dismiss()
    }

    private func recordUndoSnapshot(title previousTitle: String, content previousContent: String) {
        guard !isApplyingUndo else { return }

        let previousSnapshot = MemoEditorSnapshot(title: previousTitle, content: previousContent)
        let currentSnapshot = MemoEditorSnapshot(title: title, content: content)
        guard previousSnapshot != currentSnapshot else { return }
        guard undoStack.last != previousSnapshot else { return }

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

    private func addSticker(assetName: String) {
        let sticker = PlacedEditorSticker(assetName: assetName)
        placedStickers.append(sticker)
        selectedStickerID = sticker.id
        stickerDeletePromptID = nil

        withAnimation(.easeOut(duration: 0.18)) {
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

private struct EditorStickerOption: Identifiable {
    let assetName: String
    let title: String

    var id: String {
        assetName
    }
}

private struct PlacedEditorSticker: Identifiable, Equatable {
    private static let baseSize: CGFloat = 120
    private static let wrapPadding: CGFloat = 6
    private static let wrapVisualScale: CGFloat = 1.02

    let id = UUID()
    let assetName: String
    var position: CGPoint = CGPoint(x: 254, y: 184)
    var scale: CGFloat = 1
    var rotation: Angle = .zero

    var displaySize: CGFloat {
        Self.baseSize * scale
    }

    var textExclusionRect: CGRect {
        let size = displaySize * Self.wrapVisualScale + Self.wrapPadding * 2
        return CGRect(
            x: position.x - size / 2,
            y: position.y - size / 2,
            width: size,
            height: size
        )
    }

    var deleteBubbleY: CGFloat {
        let preferredY = position.y - displaySize / 2 - 24
        if preferredY < 22 {
            return position.y + displaySize / 2 + 24
        }

        return preferredY
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

struct MemoBodyTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var calculatedHeight: CGFloat

    let font: UIFont
    let textColor: UIColor
    let lineSpacing: CGFloat
    let exclusionRects: [CGRect]

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.isOpaque = false
        textView.font = font
        textView.textColor = textColor
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.contentInset = .zero
        textView.scrollIndicatorInsets = .zero
        textView.isScrollEnabled = false
        textView.alwaysBounceVertical = false
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.typingAttributes = textAttributes
        textView.textContainer.exclusionPaths = exclusionPaths(for: textView)
        textView.attributedText = attributedString(for: text)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        textView.font = font
        textView.textColor = textColor
        textView.typingAttributes = textAttributes
        textView.isScrollEnabled = false
        textView.textContainer.exclusionPaths = exclusionPaths(for: textView)

        defer {
            updateHeight(for: textView)
        }

        guard textView.text != text else { return }

        let selectedRange = textView.selectedRange
        textView.attributedText = attributedString(for: text)
        textView.selectedRange = clampedRange(selectedRange, in: text)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private var textAttributes: [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        paragraphStyle.lineBreakMode = .byWordWrapping

        return [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]
    }

    private func attributedString(for text: String) -> NSAttributedString {
        NSAttributedString(string: text, attributes: textAttributes)
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

    private func exclusionPaths(for textView: UITextView) -> [UIBezierPath] {
        let containerWidth = textView.bounds.width
        guard containerWidth > 0 else { return [] }

        return exclusionRects.compactMap { rect in
            let boundedRect = rect.intersection(
                CGRect(
                    x: 0,
                    y: 0,
                    width: containerWidth,
                    height: max(textView.bounds.height, calculatedHeight)
                )
            )
            guard !boundedRect.isNull, boundedRect.width > 0, boundedRect.height > 0 else {
                return nil
            }

            return UIBezierPath(rect: boundedRect)
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        private var parent: MemoBodyTextView

        init(_ parent: MemoBodyTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            parent.updateHeight(for: textView)
        }
    }
}

import SwiftUI

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

extension AnyTransition {
    static var formatPanelReveal: AnyTransition {
        .modifier(
            active: FormatPanelRevealModifier(progress: 0),
            identity: FormatPanelRevealModifier(progress: 1)
        )
        .combined(with: .opacity)
    }
}

struct EditorFormatPanelView: View {
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

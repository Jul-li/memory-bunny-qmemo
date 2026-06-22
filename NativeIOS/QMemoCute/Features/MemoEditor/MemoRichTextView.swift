import SwiftUI
import UIKit

struct MemoBodyTextView: UIViewRepresentable {
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

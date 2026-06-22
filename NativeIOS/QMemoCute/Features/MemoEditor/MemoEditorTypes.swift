import SwiftUI
import UIKit

struct MemoEditorSnapshot: Equatable {
    let title: String
    let content: String
}

enum EditorBlockStyle: String, CaseIterable {
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

enum EditorInlineStyle: String, Hashable {
    case bold
    case italic
    case underline
    case strikethrough
}

enum EditorTextColor: String, CaseIterable, Hashable {
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
struct EditorTextStyleOption: Identifiable {
    let style: EditorBlockStyle
    let title: String
    let font: Font

    var id: String {
        style.rawValue
    }
}

struct EditorInlineStyleOption: Identifiable {
    let style: EditorInlineStyle
    let title: String
    let assetName: String

    var id: String {
        style.rawValue
    }
}

struct EditorFormatCommand: Equatable {
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

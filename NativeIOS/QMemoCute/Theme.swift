import SwiftUI

enum Theme {
    enum Colors {
        static let background = Color(hex: "FFF6D7")
        static let surface = Color(hex: "FFFDF6")
        static let surfaceStrong = Color(hex: "FFFFFF")
        static let text = Color(hex: "49392F")
        static let muted = Color(hex: "9C8577")
        static let line = Color(hex: "F2DFBF")
        static let shadow = Color(hex: "C69C6D")
        static let memoCard = Color(hex: "FFFDF5")
        static let cream = Color(hex: "FFF0B8")
        static let pink = Color(hex: "FFD7E5")
        static let mint = Color(hex: "CFF5DD")
        static let sky = Color(hex: "CFEAFF")
        static let lavender = Color(hex: "E5D8FF")
        static let accent = Color(hex: "FF9DB8")
        static let accentStrong = Color(hex: "F06F9A")
    }
}

struct QMemoGlassBackground<S: InsettableShape>: View {
    let shape: S
    var tintOpacity: Double = 0.24
    var fallbackFillOpacity: Double = 0.74
    var strokeOpacity: Double = 0.62
    var lineOpacity: Double = 0.18

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                shape
                    .fill(Theme.Colors.surfaceStrong.opacity(0.14))
                    .glassEffect(
                        .regular
                            .tint(Theme.Colors.background.opacity(tintOpacity))
                            .interactive(false),
                        in: shape
                    )
            } else {
                shape
                    .fill(.regularMaterial)
                    .overlay(shape.fill(Theme.Colors.surfaceStrong.opacity(fallbackFillOpacity)))
            }
        }
        .overlay(shape.stroke(.white.opacity(strokeOpacity), lineWidth: 1))
        .overlay(shape.stroke(Theme.Colors.line.opacity(lineOpacity), lineWidth: 1))
    }
}

struct QMemoGlassScrim: View {
    var tintOpacity: Double = 0.22

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .glassEffect(
                        .regular
                            .tint(Theme.Colors.background.opacity(tintOpacity))
                            .interactive(false),
                        in: Rectangle()
                    )
            } else {
                Rectangle()
                    .fill(.ultraThinMaterial)
            }
        }
        .overlay(Theme.Colors.cream.opacity(0.18))
    }
}

@ViewBuilder
func qMemoChromeMaterial<Mask: View>(tintOpacity: Double = 0.18, mask: Mask) -> some View {
    Group {
        if #available(iOS 26.0, *) {
            Rectangle()
                .fill(.regularMaterial)
                .glassEffect(
                    .regular
                        .tint(Theme.Colors.background.opacity(tintOpacity))
                        .interactive(false),
                    in: Rectangle()
                )
        } else {
            Rectangle()
                .fill(.regularMaterial)
        }
    }
    .mask(mask)
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var value: UInt64 = 0
        scanner.scanHexInt64(&value)
        let red = Double((value >> 16) & 0xff) / 255
        let green = Double((value >> 8) & 0xff) / 255
        let blue = Double(value & 0xff) / 255
        self.init(red: red, green: green, blue: blue)
    }
}

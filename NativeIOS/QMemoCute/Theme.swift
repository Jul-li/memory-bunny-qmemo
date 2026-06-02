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

struct DeleteConfirmationOverlay: View {
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            QMemoGlassScrim(tintOpacity: 0.20)
                .opacity(0.68)
                .ignoresSafeArea()

            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    onCancel()
                }

            ZStack(alignment: .top) {
                VStack(spacing: 18) {
                    Text("便签删除后将无法恢复！确定删除当前便签吗？")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(Theme.Colors.text)
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .padding(.horizontal, 8)
                        .padding(.top, 54)

                    HStack(spacing: 12) {
                        Button {
                            onConfirm()
                        } label: {
                            Text("确认删除")
                                .font(.system(size: 16, weight: .black))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Theme.Colors.accentStrong)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            onCancel()
                        } label: {
                            Text("取消")
                                .font(.system(size: 16, weight: .black))
                                .foregroundStyle(Theme.Colors.text)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Theme.Colors.surfaceStrong.opacity(0.70))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 18)
                .background(
                    QMemoGlassBackground(
                        shape: RoundedRectangle(cornerRadius: 30, style: .continuous),
                        tintOpacity: 0.20,
                        fallbackFillOpacity: 0.86,
                        strokeOpacity: 0.66,
                        lineOpacity: 0.12
                    )
                )
                .shadow(color: Theme.Colors.shadow.opacity(0.18), radius: 24, y: 10)
                .padding(.top, 54)

                Image("PopDelete")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 112, height: 112)
                    .offset(y: -2)
                    .allowsHitTesting(false)
            }
            .padding(.horizontal, 34)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
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

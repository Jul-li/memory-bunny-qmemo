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

import SwiftUI

enum AnthemTheme {
    static let background = Color(hex: 0x090B0F)
    static let workspaceTop = Color(hex: 0x0C0F14)
    static let toolbar = Color(hex: 0x11141A)
    static let sidebar = Color(hex: 0x0E1116)
    static let inspector = Color(hex: 0x0E1116)
    static let panel = Color(hex: 0x11151B)
    static let waveformBackground = Color(hex: 0x05070A)
    static let border = Color(hex: 0x282D36)
    static let divider = Color(hex: 0x252A32)
    static let textPrimary = Color(hex: 0xF4F6F8)
    static let textSecondary = Color(hex: 0x929BA8)
    static let textMuted = Color(hex: 0x77818D)
    static let navigationSelected = Color(hex: 0x1C4080)
    static let actionBlue = Color(hex: 0x397CE8)
    static let waveformBright = Color(hex: 0x4EA0FF)
    static let waveformDeep = Color(hex: 0x1560BE)
    static let anthem = Color(hex: 0xD44822)
    static let anthemHighlight = Color(hex: 0xFF643D)

    static let workspaceGradient = LinearGradient(
        colors: [workspaceTop, background], startPoint: .top, endPoint: .bottom
    )
}

enum AnthemSpacing {
    static let xs: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let standard: CGFloat = 16
    static let section: CGFloat = 20
    static let workspace: CGFloat = 24
    static let large: CGFloat = 32
}

enum AnthemLayout {
    static let minimumWindowWidth: CGFloat = 900
    static let minimumWindowHeight: CGFloat = 600
    static let preferredWindowWidth: CGFloat = 1200
    static let preferredWindowHeight: CGFloat = 750
    static let sidebarWidth: CGFloat = 178
    static let inspectorWidth: CGFloat = 225
    static let navigationRowHeight: CGFloat = 36
    static let navigationCornerRadius: CGFloat = 7
}

enum AnthemTypography {
    static let trackTitle = Font.system(size: 25, weight: .bold)
    static let inspectorHeading = Font.system(size: 11, weight: .bold)
    static let inspectorLabel = Font.system(size: 9, weight: .bold)
    static let inspectorValue = Font.system(size: 13)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

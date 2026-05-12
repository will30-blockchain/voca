import SwiftUI

/// Centralised visual tokens. Intentionally minimal — "Typeless-style":
/// subtle gradients on neutral surfaces, no neon, no skeuomorphism.
enum DesignTokens {
    enum Color {
        static let surface = SwiftUI.Color(nsColor: .windowBackgroundColor)
        static let surfaceElevated = SwiftUI.Color(nsColor: .underPageBackgroundColor)
        static let accent = SwiftUI.Color.accentColor
        static let recording = SwiftUI.Color(red: 0.95, green: 0.34, blue: 0.34)
        static let translate = SwiftUI.Color(red: 0.36, green: 0.65, blue: 0.95)
        static let muted = SwiftUI.Color.secondary
        static let border = SwiftUI.Color.primary.opacity(0.08)
    }

    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 14
    }

    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 20
        static let xl: CGFloat = 28
    }

    enum Font {
        static let title = SwiftUI.Font.system(size: 17, weight: .semibold, design: .rounded)
        static let body = SwiftUI.Font.system(size: 13, weight: .regular)
        static let caption = SwiftUI.Font.system(size: 11, weight: .regular)
        static let mono = SwiftUI.Font.system(size: 12, weight: .regular, design: .monospaced)
    }
}

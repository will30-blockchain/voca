import SwiftUI

/// VOCA visual system — derived from SuperCard's "Professional Warmth"
/// design language. White surfaces, warm orange (#ea580c) primary accent,
/// SF Pro at business-friendly minimum 12 pt, glass cards on light bg.
///
/// Aesthetic kin: Things 3 (warmth, generous whitespace), Linear (typography
/// hierarchy), Bear (cards as primary container). Anti-references: SuperWhisper
/// neon, Wispr Flow gradient saturation.
enum DesignTokens {
    enum Color {
        // Brand accent — used for primary CTAs, focus rings, recording state.
        static let accent = SwiftUI.Color(red: 0xEA / 255, green: 0x58 / 255, blue: 0x0C / 255)
        static let accentSoft = SwiftUI.Color(red: 0xFB / 255, green: 0x92 / 255, blue: 0x3C / 255)
        static let accentTint = SwiftUI.Color(red: 0xFF / 255, green: 0xF1 / 255, blue: 0xE6 / 255)

        // Mode accents — matches the SC per-tab pattern: one accent per screen.
        static let recording = accent
        static let translate = SwiftUI.Color(red: 0x0E / 255, green: 0xA5 / 255, blue: 0xE9 / 255)

        // Surfaces — neutral warm whites that read as paper, not screen.
        static let surface = SwiftUI.Color(red: 0xFE / 255, green: 0xFD / 255, blue: 0xFB / 255)
        static let surfaceElevated = SwiftUI.Color.white
        static let surfaceSunken = SwiftUI.Color(red: 0xFA / 255, green: 0xF7 / 255, blue: 0xF2 / 255)

        // Text — warm near-black for body, warm grays for hierarchy.
        static let textPrimary = SwiftUI.Color(red: 0x1A / 255, green: 0x16 / 255, blue: 0x10 / 255)
        static let textSecondary = SwiftUI.Color(red: 0x52 / 255, green: 0x4B / 255, blue: 0x42 / 255)
        static let textTertiary = SwiftUI.Color(red: 0x8A / 255, green: 0x82 / 255, blue: 0x78 / 255)

        // Borders — soft warm gray hairlines.
        static let border = SwiftUI.Color(red: 0xE7 / 255, green: 0xE2 / 255, blue: 0xDA / 255)
        static let borderSubtle = SwiftUI.Color(red: 0xF1 / 255, green: 0xEC / 255, blue: 0xE4 / 255)

        // Status.
        static let muted = textSecondary
        static let danger = SwiftUI.Color(red: 0xDC / 255, green: 0x26 / 255, blue: 0x26 / 255)
        static let warning = SwiftUI.Color(red: 0xD9 / 255, green: 0x77 / 255, blue: 0x06 / 255)
        static let success = SwiftUI.Color(red: 0x05 / 255, green: 0x96 / 255, blue: 0x69 / 255)
    }

    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 12   // SC card radius
        static let lg: CGFloat = 16
        static let pill: CGFloat = 22
    }

    enum Space {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16   // SC page padding
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    /// Typography scale — SF Pro everywhere, business-friendly minimums.
    /// 12 pt is the smallest size used (SC rule: target middle-aged business
    /// professionals — readability first).
    enum Typography {
        static let display = Font.system(size: 28, weight: .semibold, design: .default)
        static let title = Font.system(size: 22, weight: .semibold, design: .default)
        static let title2 = Font.system(size: 17, weight: .semibold, design: .default)
        static let headline = Font.system(size: 15, weight: .semibold, design: .default)
        static let body = Font.system(size: 13, weight: .regular, design: .default)
        static let bodyEmphasis = Font.system(size: 13, weight: .medium, design: .default)
        static let caption = Font.system(size: 12, weight: .regular, design: .default)
        static let captionEmphasis = Font.system(size: 12, weight: .semibold, design: .default)
        static let mono = Font.system(size: 12, weight: .regular, design: .monospaced)
        static let monoEmphasis = Font.system(size: 12, weight: .medium, design: .monospaced)
    }

    enum Shadow {
        /// Subtle card lift — used for elevated surfaces sitting on the page bg.
        static func card<S: ShapeStyle>(in shape: S) -> some View {
            EmptyView() // kept for parity; cards use direct .shadow modifier
        }
    }

    enum Animation {
        static let snappy = SwiftUI.Animation.spring(response: 0.28, dampingFraction: 0.78)
        static let gentle = SwiftUI.Animation.easeInOut(duration: 0.22)
        static let meter = SwiftUI.Animation.easeOut(duration: 0.08)
    }
}

// MARK: - Reusable surfaces

/// Standard card container — flat white surface with a single hairline
/// border. No shadow: the user explicitly asked for a "no AI" look — flat
/// surfaces, no lift, no glow.
struct Card<Content: View>: View {
    let content: Content
    var padding: CGFloat = DesignTokens.Space.lg
    init(padding: CGFloat = DesignTokens.Space.lg, @ViewBuilder _ content: () -> Content) {
        self.padding = padding
        self.content = content()
    }
    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                    .fill(DesignTokens.Color.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                    .stroke(DesignTokens.Color.border, lineWidth: 0.5)
            )
    }
}

/// Section header — semantic title above a card or list.
struct SectionTitle: View {
    let text: String
    var trailing: AnyView?
    init(_ text: String, trailing: AnyView? = nil) {
        self.text = text
        self.trailing = trailing
    }
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text)
                .font(DesignTokens.Typography.title2)
                .foregroundStyle(DesignTokens.Color.textPrimary)
            Spacer(minLength: 0)
            if let trailing { trailing }
        }
    }
}

// Color usage helpers — read like English in the call site.
extension View {
    func vtPrimaryText() -> some View { foregroundStyle(DesignTokens.Color.textPrimary) }
    func vtSecondaryText() -> some View { foregroundStyle(DesignTokens.Color.textSecondary) }
    func vtTertiaryText() -> some View { foregroundStyle(DesignTokens.Color.textTertiary) }
}

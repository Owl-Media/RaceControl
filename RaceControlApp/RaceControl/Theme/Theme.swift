import SwiftUI

/// Central design system for RaceControl.
///
/// Dark-first palette tuned for OLED (near-black surfaces), an F1-red accent,
/// and semantic colours that adapt to light/dark automatically. Spacing and
/// radii follow an 8pt grid per Apple's HIG.
enum Theme {

    // MARK: Brand palette
    enum Palette {
        /// Signature Formula 1 red. Brand fills, tints and large text only —
        /// at 3.6:1 on surface it fails WCAG AA for small text.
        static let racingRed = Color(hex: "E10600")
        static let racingRedDim = Color(hex: "B00500")
        /// Lighter red tint for *small* text (5.9:1 on surface — passes AA).
        static let racingRedText = Color(hex: "FF5A50")

        /// OLED-friendly backgrounds (near-black, avoids scroll smear of pure #000).
        static let background = Color(hex: "0A0A0C")
        static let surface = Color(hex: "16161A")
        static let surfaceElevated = Color(hex: "202027")
        static let stroke = Color.white.opacity(0.08)

        // Text
        // Contrast on surface (#16161A): 16.2:1 / 7.0:1 / 5.3:1 — all pass WCAG AA.
        static let textPrimary = Color(hex: "F2F2F5")
        static let textSecondary = Color(hex: "A0A0AA")
        static let textTertiary = Color(hex: "8A8A94")

        // Semantic
        static let positive = Color(hex: "30D158")
        static let negative = Color(hex: "FF453A")
        static let warning = Color(hex: "FF9F0A")
        static let info = Color(hex: "64D2FF")

        // Tyre compounds (official F1 colours)
        static let tyreSoft = Color(hex: "F0402C")
        static let tyreMedium = Color(hex: "F5D000")
        static let tyreHard = Color(hex: "EBEBEB")
        static let tyreIntermediate = Color(hex: "40B14B")
        static let tyreWet = Color(hex: "1E6FE0")
    }

    // MARK: Spacing (8pt grid)
    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    // MARK: Corner radii
    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 14
        static let lg: CGFloat = 20
        static let pill: CGFloat = 999
    }

    /// Minimum HIG touch target.
    static let minTouch: CGFloat = 44
}

// MARK: - Hex color support
extension Color {
    /// Create a Color from a hex string like `#E10600` or `E10600`.
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# ")).uppercased()
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r, g, b, a: Double
        switch cleaned.count {
        case 8: // RRGGBBAA
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255
            a = Double(value & 0xFF) / 255
        default: // RRGGBB (or fallback)
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    /// Build a team colour from an optional backend hex, falling back to red.
    static func team(_ hex: String?) -> Color {
        guard let hex, !hex.isEmpty else { return Theme.Palette.racingRed }
        return Color(hex: hex)
    }
}

// MARK: - Tyre compound helper
enum TyreCompound {
    static func color(_ compound: String?) -> Color {
        switch (compound ?? "").uppercased() {
        case "SOFT": return Theme.Palette.tyreSoft
        case "MEDIUM": return Theme.Palette.tyreMedium
        case "HARD": return Theme.Palette.tyreHard
        case "INTERMEDIATE": return Theme.Palette.tyreIntermediate
        case "WET": return Theme.Palette.tyreWet
        default: return Theme.Palette.textTertiary
        }
    }

    static func letter(_ compound: String?) -> String {
        guard let c = compound?.uppercased().first else { return "?" }
        return String(c)
    }
}

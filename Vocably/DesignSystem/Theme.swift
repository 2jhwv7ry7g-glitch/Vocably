import SwiftUI
import UIKit

// MARK: - Design tokens (IOS_BUILD_HANDOFF §5)
// Single source of truth for colour, spacing, radius and type. Views must never
// hardcode hex — read from `Color.vocably.*`. Colours are dynamic (light + dark,
// §5.1 / §5.2) so Dark Mode parity is automatic.

private extension UIColor {
    /// Build a UIColor from a 0xRRGGBB hex.
    convenience init(hex: UInt32) {
        self.init(
            red:   CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue:  CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

private func dynamic(light: UInt32, dark: UInt32) -> Color {
    Color(UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
    })
}

extension Color {
    /// Semantic palette — botanical "bone × moss" (§5).
    enum vocably {
        static let background    = dynamic(light: 0xF4F1E8, dark: 0x15170E)
        static let surface       = dynamic(light: 0xFBF9F3, dark: 0x1C1F16)
        static let surfaceBright  = dynamic(light: 0xFFFFFF, dark: 0x20241A)
        static let ink           = dynamic(light: 0x21241D, dark: 0xF5F4EE)
        static let muted         = dynamic(light: 0x767A6C, dark: 0x9DA08F)
        static let faint         = dynamic(light: 0xA6A99B, dark: 0x6E7264)
        static let line          = dynamic(light: 0xE6E2D6, dark: 0x2C3025)
        static let onPrimary     = dynamic(light: 0xF4F1E8, dark: 0x15170E)
        static let primary       = dynamic(light: 0x34553B, dark: 0x7DA878)
        static let primaryStrong = dynamic(light: 0x284230, dark: 0x4E7B57)
        static let primarySoft   = dynamic(light: 0xE2E8D7, dark: 0x2A3A2C)
        static let accent        = dynamic(light: 0xC68A36, dark: 0xC68A36)
        static let accentSoft    = dynamic(light: 0xF1E5CC, dark: 0x3A3320)
        static let rose          = dynamic(light: 0xB05B45, dark: 0xC56B53)
    }
}

// MARK: - Spacing & radius (§5.4)

enum Space {
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 20
    static let s6: CGFloat = 24
    static let s8: CGFloat = 32
    static let s10: CGFloat = 40
    static let s12: CGFloat = 48
}

enum Radius {
    static let sm: CGFloat = 10
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let full: CGFloat = 999
}

// MARK: - Type (§5.3) — Fraunces→serif, Inter→system (the §11.4 SF-Pro fallback)

extension Font {
    /// Display / vocabulary serif (Fraunces stand-in), Dynamic-Type aware.
    static func display(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    /// UI text (Inter stand-in), Dynamic-Type aware.
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

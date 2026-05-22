import SwiftUI

// MARK: - Editorial Color Palette
//
// Warm, paper-like cream background with muted ink-style text and
// terracotta accents. Class chips use deeply saturated but desaturated
// colors that look good on cream.

extension Color {
    // Surfaces
    static let fpBg          = Color(red: 0.961, green: 0.949, blue: 0.918) // #F5F2EB cream
    static let fpBgRaised    = Color(red: 0.973, green: 0.965, blue: 0.941) // slightly lighter cream
    static let fpDivider     = Color(red: 0.847, green: 0.831, blue: 0.792) // warm light gray

    // Ink
    static let fpInk         = Color(red: 0.102, green: 0.098, blue: 0.086) // near-black, warm
    static let fpInkMuted    = Color(red: 0.380, green: 0.365, blue: 0.329) // mid warm gray
    static let fpInkSubtle   = Color(red: 0.561, green: 0.541, blue: 0.490) // light warm gray

    // Accents — used for class color dots, urgency, today highlight
    static let fpAccent      = Color(red: 0.753, green: 0.298, blue: 0.176) // terracotta
    static let fpGreen       = Color(red: 0.247, green: 0.337, blue: 0.224) // dark forest
    static let fpMustard     = Color(red: 0.659, green: 0.557, blue: 0.239) // ochre
    static let fpBlue        = Color(red: 0.310, green: 0.404, blue: 0.498) // dusty blue
    static let fpPurple      = Color(red: 0.443, green: 0.337, blue: 0.510) // muted plum
}

// MARK: - Font helpers

extension Font {
    /// Big serif headline, like a magazine title.
    static func fpHeadline(_ size: CGFloat = 32) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }

    /// Monospaced caption (weekday labels, dates, due-text).
    static func fpMono(_ size: CGFloat = 11, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// Plain body — used for item titles.
    static func fpBody(_ size: CGFloat = 14, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight)
    }
}

// MARK: - Palette → editorial mapping

/// Map an arbitrary Color (from the user's period color) to the closest
/// editorial palette accent so dots look harmonious. Falls through to the
/// original color if no match is close enough.
extension Color {
    static let fpPeriodPalette: [Color] = [
        .fpAccent, .fpGreen, .fpMustard, .fpBlue, .fpPurple,
    ]
}

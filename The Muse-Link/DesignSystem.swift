//
//  DesignSystem.swift
//  The Muse-Link
//
//  Museum-elegant palette: cream parchment, ink black, oxblood accent.
//  Serif headlines (New York), SF for body.
//

import SwiftUI

enum MuseTheme {
    // Palette
    static let parchment   = Color(red: 0.97, green: 0.94, blue: 0.88)
    static let parchmentDk = Color(red: 0.93, green: 0.89, blue: 0.81)
    static let ink         = Color(red: 0.10, green: 0.09, blue: 0.08)
    static let inkSoft     = Color(red: 0.28, green: 0.25, blue: 0.22)
    static let oxblood     = Color(red: 0.45, green: 0.13, blue: 0.13)
    static let brass       = Color(red: 0.70, green: 0.55, blue: 0.27)
    static let hairline    = Color(red: 0.78, green: 0.72, blue: 0.62)

    // Spacing
    static let pad: CGFloat = 16
    static let padL: CGFloat = 24
    static let corner: CGFloat = 14

    // Typography
    static func display(_ size: CGFloat = 34) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }
    static func title(_ size: CGFloat = 22) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }
    static func label(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .medium, design: .default)
            .smallCaps()
    }
    static func body(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }
    static func bodySerif(_ size: CGFloat = 17) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }
}

// MARK: - View modifiers

struct ParchmentBackground: ViewModifier {
    func body(content: Content) -> some View {
        content.background(
            LinearGradient(
                colors: [MuseTheme.parchment, MuseTheme.parchmentDk],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()
        )
    }
}

struct WallLabelCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(MuseTheme.pad)
            .background(
                RoundedRectangle(cornerRadius: MuseTheme.corner, style: .continuous)
                    .fill(Color.white.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: MuseTheme.corner, style: .continuous)
                    .stroke(MuseTheme.hairline.opacity(0.6), lineWidth: 0.5)
            )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .default))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(MuseTheme.oxblood.opacity(configuration.isPressed ? 0.85 : 1))
            .foregroundColor(MuseTheme.parchment)
            .clipShape(RoundedRectangle(cornerRadius: MuseTheme.corner, style: .continuous))
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white.opacity(configuration.isPressed ? 0.4 : 0.65))
            .foregroundColor(MuseTheme.ink)
            .overlay(
                RoundedRectangle(cornerRadius: MuseTheme.corner, style: .continuous)
                    .stroke(MuseTheme.hairline, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: MuseTheme.corner, style: .continuous))
    }
}

struct ChipStyle: ViewModifier {
    let selected: Bool
    func body(content: Content) -> some View {
        content
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(selected ? MuseTheme.ink : Color.white.opacity(0.6))
            )
            .foregroundColor(selected ? MuseTheme.parchment : MuseTheme.ink)
            .overlay(
                Capsule().stroke(MuseTheme.hairline, lineWidth: selected ? 0 : 0.5)
            )
    }
}

extension View {
    func parchment() -> some View { modifier(ParchmentBackground()) }
    func wallLabel() -> some View { modifier(WallLabelCard()) }
    func chip(selected: Bool = false) -> some View { modifier(ChipStyle(selected: selected)) }
}

// Hairline divider used as a wall-label rule.
struct HairlineRule: View {
    var body: some View {
        Rectangle()
            .fill(MuseTheme.hairline.opacity(0.7))
            .frame(height: 0.5)
    }
}

// Small section header in the wall-label voice.
struct SectionHeader: View {
    let title: String
    let subtitle: String?
    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(MuseTheme.label())
                .tracking(1.2)
                .foregroundColor(MuseTheme.inkSoft)
            if let subtitle {
                Text(subtitle)
                    .font(MuseTheme.title(20))
                    .foregroundColor(MuseTheme.ink)
            }
        }
    }
}

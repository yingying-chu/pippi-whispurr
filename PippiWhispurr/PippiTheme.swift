//
//  PippiTheme.swift
//  PippiWhispurr
//
//  Pa'lais x SayBriefly v7 design tokens.
//

import SwiftUI

struct VerticalScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension Color {
    static let forestInk = Color("ForestInk")
    static let cream = Color("Cream")
    static let honeyYellow = Color("HoneyYellow")
    static let mintSage = Color("MintSage")
    static let softTeal = Color(hex: "5fbfbf")
    static let stickyLavender = Color(hex: "e8b4ee")
    static let blobOrange = Color("BlobOrange")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let red = Double((int >> 16) & 0xFF) / 255
        let green = Double((int >> 8) & 0xFF) / 255
        let blue = Double(int & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}

enum PippiWeight {
    case regular
    case semibold
    case extraBold

    var fontName: String {
        switch self {
        case .regular: return "BricolageGrotesque-Regular"
        case .semibold: return "BricolageGrotesque-SemiBold"
        case .extraBold: return "BricolageGrotesque-ExtraBold"
        }
    }
}

extension Font {
    static func pippi(_ size: CGFloat, weight: PippiWeight = .regular) -> Font {
        .custom(weight.fontName, size: size)
    }

    static func pippiScript(_ size: CGFloat) -> Font {
        .custom("Caveat-Regular", size: size)
    }
}

extension CGFloat {
    static let radiusPill: CGFloat = 32
    static let radiusCard: CGFloat = 12
    static let radiusTag: CGFloat = 16
    static let radiusPhoto: CGFloat = 8
}

struct PippiPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.pippi(15, weight: .semibold))
            .foregroundColor(.cream)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                configuration.isPressed
                    ? Color.forestInk.opacity(0.8)
                    : Color.forestInk
            )
            .clipShape(Capsule())
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct PippiOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.pippi(13, weight: .semibold))
            .foregroundColor(.forestInk)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(Color.cream)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.forestInk, lineWidth: 1.5))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct PippiCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: .radiusCard, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: .radiusCard, style: .continuous)
                    .stroke(Color.forestInk.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.07), radius: 14, x: -6, y: 6)
    }
}

extension View {
    func pippiCard() -> some View {
        modifier(PippiCard())
    }
}

extension UITabBarAppearance {
    static func pippiAppearance() -> UITabBarAppearance {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.cream)

        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = UIColor(Color.forestInk.opacity(0.35))
        itemAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(Color.forestInk.opacity(0.35))
        ]
        itemAppearance.selected.iconColor = UIColor(Color.forestInk)
        itemAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(Color.forestInk)
        ]
        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance
        return appearance
    }
}

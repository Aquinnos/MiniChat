//
//  Theme.swift
//  MiniChat
//
//  Kolory dla obu motywów + ThemeColors (light/dark warianty).
//  W widokach używaj przez @EnvironmentObject ThemeManager + colors.
//

import SwiftUI

struct AppColors {
    let background: Color
    let surface: Color
    let gold: Color
    let goldSoft: Color
    let blue: Color
    let blueSoft: Color
    let textPrimary: Color
    let textSecondary: Color
    let bubbleShadow: Color
    let userBubbleGradient: LinearGradient
    let assistantBubbleGradient: LinearGradient

    static let light = AppColors(
        background: Color(red: 0.98, green: 0.97, blue: 0.95),
        surface: .white,
        gold: Color(red: 0.95, green: 0.78, blue: 0.20),
        goldSoft: Color(red: 1.00, green: 0.93, blue: 0.70),
        blue: Color(red: 0.10, green: 0.45, blue: 0.95),
        blueSoft: Color(red: 0.78, green: 0.88, blue: 1.00),
        textPrimary: Color(red: 0.10, green: 0.10, blue: 0.15),
        textSecondary: Color(red: 0.45, green: 0.45, blue: 0.50),
        bubbleShadow: Color.black.opacity(0.10),
        userBubbleGradient: LinearGradient(
            colors: [Color(red: 0.10, green: 0.45, blue: 0.95), Color(red: 0.20, green: 0.55, blue: 0.98)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        assistantBubbleGradient: LinearGradient(
            colors: [Color(red: 1.00, green: 0.93, blue: 0.70), Color(red: 1.00, green: 0.96, blue: 0.85)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )

    static let dark = AppColors(
        background: Color(red: 0.08, green: 0.08, blue: 0.10),
        surface: Color(red: 0.14, green: 0.14, blue: 0.17),
        gold: Color(red: 1.00, green: 0.82, blue: 0.30),
        goldSoft: Color(red: 0.35, green: 0.28, blue: 0.12),
        blue: Color(red: 0.40, green: 0.70, blue: 1.00),
        blueSoft: Color(red: 0.18, green: 0.25, blue: 0.40),
        textPrimary: Color(red: 0.95, green: 0.95, blue: 0.98),
        textSecondary: Color(red: 0.65, green: 0.65, blue: 0.70),
        bubbleShadow: Color.black.opacity(0.4),
        userBubbleGradient: LinearGradient(
            colors: [Color(red: 0.20, green: 0.45, blue: 0.85), Color(red: 0.30, green: 0.55, blue: 0.95)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        assistantBubbleGradient: LinearGradient(
            colors: [Color(red: 0.30, green: 0.24, blue: 0.10), Color(red: 0.40, green: 0.32, blue: 0.15)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}

/// Backward-compatibility layer - stare `Theme.xxx` API deleguje do ThemeManager.shared
/// z domyślnym light scheme. Nowe widoki powinny używać EnvironmentObject.
enum Theme {
    static let gold = AppColors.light.gold
    static let goldSoft = AppColors.light.goldSoft
    static let blue = AppColors.light.blue
    static let blueSoft = AppColors.light.blueSoft
    static let background = AppColors.light.background
    static let surface = AppColors.light.surface
    static let textPrimary = AppColors.light.textPrimary
    static let textSecondary = AppColors.light.textSecondary
    static let userBubble = AppColors.light.userBubbleGradient
    static let assistantBubble = AppColors.light.assistantBubbleGradient
}

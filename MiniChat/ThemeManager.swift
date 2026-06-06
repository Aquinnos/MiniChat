//
//  ThemeManager.swift
//  MiniChat
//
//  Zarządzanie motywem (light/dark/system) z persystencją w UserDefaults.
//

import SwiftUI
import Combine

enum AppThemeMode: String, CaseIterable, Identifiable, Codable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "Systemowy"
        case .light: return "Jasny"
        case .dark: return "Ciemny"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var mode: AppThemeMode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: "themeMode")
        }
    }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: "themeMode"),
           let parsed = AppThemeMode(rawValue: raw) {
            self.mode = parsed
        } else {
            self.mode = .system
        }
    }

    /// Zwraca schemat kolorów dla danego trybu i aktualnego colorScheme
    func colors(for colorScheme: ColorScheme) -> AppColors {
        switch mode {
        case .light: return .light
        case .dark: return .dark
        case .system: return colorScheme == .dark ? .dark : .light
        }
    }
}

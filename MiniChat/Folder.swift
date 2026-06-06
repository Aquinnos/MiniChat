//
//  Folder.swift
//  MiniChat
//
//  Folder = kolekcja konwersacji. Flat lista (bez nesting), z emoji + kolorem.
//

import Foundation
import SwiftUI

struct Folder: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var emoji: String
    var colorHex: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        emoji: String = "📁",
        colorHex: String = "#FFD700",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.colorHex = colorHex
        self.createdAt = createdAt
    }

    var color: Color {
        Color(hex: colorHex) ?? Theme.gold
    }
}

/// Presety kolorów dla folderów
enum FolderColor {
    static let presets: [String] = [
        "#FFD700",  // złoty
        "#007AFF",  // niebieski
        "#34C759",  // zielony
        "#FF9500",  // pomarańczowy
        "#FF3B30",  // czerwony
        "#AF52DE",  // fioletowy
        "#FF2D55",  // różowy
        "#5856D6"   // indydeo
    ]
}

/// Rozszerzenie Color żeby parsował hex
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let length = hexSanitized.count
        if length == 6 {
            let r = (rgb & 0xFF0000) >> 16
            let g = (rgb & 0x00FF00) >> 8
            let b = rgb & 0x0000FF
            self.init(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
        } else if length == 8 {
            let r = (rgb & 0xFF000000) >> 24
            let g = (rgb & 0x00FF0000) >> 16
            let b = (rgb & 0x0000FF00) >> 8
            let a = rgb & 0x000000FF
            self.init(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
        } else {
            return nil
        }
    }
}

//
//  HistoryEmptyState.swift
//  MiniChat
//
//  Pusty stan: brak rozmów / brak wyników search / brak rozmów z danym tagiem.
//

import SwiftUI

struct HistoryEmptyState: View {
    let searchText: String
    let selectedTag: String?

    private var icon: String {
        if !searchText.isEmpty { return "magnifyingglass" }
        if selectedTag != nil { return "tag.slash" }
        return "tray"
    }

    private var title: String {
        if !searchText.isEmpty { return "Brak wyników" }
        if selectedTag != nil { return "Brak rozmów z tym tagiem" }
        return "Brak rozmów"
    }

    private var subtitle: String? {
        if !searchText.isEmpty {
            return "Dla \"\(searchText)\""
        }
        if let tag = selectedTag {
            return "Tag: #\(tag)"
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(Theme.textSecondary)
            Text(title)
                .font(.headline)
                .foregroundColor(Theme.textSecondary)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary.opacity(0.7))
            } else {
                Text("Zacznij nową rozmowę klikając ikonę ołówka")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
    }
}

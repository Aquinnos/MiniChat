//
//  HistoryFilterChips.swift
//  MiniChat
//
//  Paski filtrów (foldery, tagi) dla widoku historii.
//

import SwiftUI

struct FolderFilterBar: View {
    let folders: [Folder]
    @Binding var selectedFolderId: UUID?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "Wszystkie", icon: "tray.full", isActive: selectedFolderId == nil) {
                    selectedFolderId = nil
                }
                ForEach(folders) { folder in
                    FilterChip(
                        label: folder.name,
                        icon: "folder.fill",
                        isActive: selectedFolderId == folder.id,
                        activeColor: folder.color
                    ) {
                        selectedFolderId = (selectedFolderId == folder.id) ? nil : folder.id
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Theme.surface.opacity(0.5))
    }
}

struct TagFilterBar: View {
    let tags: [String]
    @Binding var selectedTag: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "Wszystkie", icon: "tray.full", isActive: selectedTag == nil) {
                    selectedTag = nil
                }
                ForEach(tags, id: \.self) { tag in
                    FilterChip(label: tag, icon: "tag", isActive: selectedTag == tag) {
                        selectedTag = (selectedTag == tag) ? nil : tag
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Theme.surface.opacity(0.5))
    }
}

struct FilterChip: View {
    let label: String
    let icon: String
    let isActive: Bool
    var activeColor: Color = Theme.gold
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(label)
                    .font(.caption.bold())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isActive ? activeColor : Theme.surface)
            .foregroundColor(isActive ? .white : Theme.textPrimary)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(isActive ? Color.clear : activeColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

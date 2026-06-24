//
//  ConversationRow.swift
//  MiniChat
//
//  Wiersz konwersacji w liście historii: initials, tytuł, badge folderu, tagi.
//

import SwiftUI

struct ConversationRow: View {
    let conversation: Conversation
    let isSelected: Bool
    var selectedTag: String? = nil
    @StateObject private var folderStore = FolderStore.shared

    private var folder: Folder? {
        guard let id = conversation.folderId else { return nil }
        return folderStore.folder(id: id)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isSelected ? Theme.blue : Theme.gold.opacity(0.3))
                    .frame(width: 40, height: 40)
                Text(initials)
                    .font(.caption.bold())
                    .foregroundColor(isSelected ? .white : Theme.textPrimary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if conversation.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundColor(Theme.gold)
                    }
                    Text(conversation.title)
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    Text("\(conversation.messages.count) wiadomości")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                    Text("·")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                    Text(conversation.updatedAt, style: .date)
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }

                tagsAndFolderRow
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Theme.blue)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var tagsAndFolderRow: some View {
        HStack(spacing: 4) {
            if let folder = folder {
                FolderBadge(folder: folder)
            }
            ForEach(conversation.tags.prefix(folder == nil ? 3 : 2), id: \.self) { tag in
                TagPill(tag: tag, isHighlighted: selectedTag == tag)
            }
            if conversation.tags.count > 3 {
                Text("+\(conversation.tags.count - 3)")
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
            }
        }
    }

    private var initials: String {
        let words = conversation.title.split(separator: " ")
        if let first = words.first?.first {
            return String(first).uppercased()
        }
        return "?"
    }
}

// MARK: - Sub-components

struct FolderBadge: View {
    let folder: Folder

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "folder.fill")
                .font(.system(size: 9))
            Text(folder.name)
                .font(.caption2.bold())
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 1)
        .background(folder.color.opacity(0.2))
        .foregroundColor(Theme.textPrimary)
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(folder.color.opacity(0.4), lineWidth: 0.5)
        )
    }
}

struct TagPill: View {
    let tag: String
    let isHighlighted: Bool

    var body: some View {
        Text("#\(tag)")
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(isHighlighted ? Theme.gold.opacity(0.3) : Theme.blue.opacity(0.15))
            .foregroundColor(isHighlighted ? Theme.textPrimary : Theme.blue)
            .clipShape(Capsule())
    }
}

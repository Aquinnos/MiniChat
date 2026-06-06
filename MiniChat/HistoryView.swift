//
//  HistoryView.swift
//  MiniChat
//
//  Lista konwersacji z: search, pin, tag filter, sortowanie.
//

import SwiftUI

struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: ConversationStore
    @StateObject private var folderStore = FolderStore.shared
    @State private var searchText: String = ""
    @State private var selectedTag: String? = nil
    @State private var selectedFolderId: UUID? = nil
    @State private var editingTagsFor: Conversation?
    @State private var showFolders: Bool = false
    @State private var movingToFolderFor: Conversation?

    var onSelect: (() -> Void)?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filtr folderów (chips) - widoczny tylko gdy jest >1 folder
                if folderStore.folders.count > 1 {
                    folderFilterBar
                }

                // Filtr tagów (chips) - widoczny tylko gdy są tagi
                if !store.allTags.isEmpty {
                    tagFilterBar
                }

                Group {
                    if searchText.isEmpty {
                        // Bez search - normalna lista
                        if filteredConversations.isEmpty {
                            emptyState
                        } else {
                            List {
                                // Pinned section
                                let pinned = filteredConversations.filter { $0.isPinned }
                                let unpinned = filteredConversations.filter { !$0.isPinned }
                                if !pinned.isEmpty {
                                    Section {
                                        ForEach(pinned) { conv in
                                            conversationButton(conv)
                                        }
                                        .onDelete(perform: nil)
                                    } header: {
                                        Label("Przypięte", systemImage: "pin.fill")
                                            .font(.caption.bold())
                                            .foregroundColor(Theme.gold)
                                    }
                                }
                                if !unpinned.isEmpty {
                                    Section {
                                        ForEach(unpinned) { conv in
                                            conversationButton(conv)
                                        }
                                        .onDelete(perform: deleteConversations)
                                    } header: {
                                        if !pinned.isEmpty {
                                            Text("Wszystkie rozmowy")
                                                .font(.caption.bold())
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        // Search mode - pokaż wyniki z snippetami
                        let results = store.search(query: searchText)
                        if results.isEmpty {
                            emptyState
                        } else {
                            List {
                                ForEach(results) { result in
                                    searchResultButton(result)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Historia")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(text: $searchText, prompt: "Szukaj w rozmowach")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gotowe") { dismiss() }
                }
                if !store.conversations.isEmpty {
                    ToolbarItem(placement: .destructiveAction) {
                        Menu {
                            Button {
                                showFolders = true
                            } label: {
                                Label("Zarządzaj folderami", systemImage: "folder.badge.gearshape")
                            }
                            Divider()
                            Button(role: .destructive) {
                                store.deleteAll()
                            } label: {
                                Label("Usuń wszystkie", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(item: $editingTagsFor) { conv in
                TagEditorSheet(conversation: conv)
            }
            .sheet(isPresented: $showFolders) {
                FoldersView()
            }
            .sheet(item: $movingToFolderFor) { conv in
                FolderPickerSheet(conversation: conv) { folderId in
                    store.setFolder(folderId, for: conv)
                }
            }
        }
    }

    // MARK: - Subviews

    private var folderFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "Wszystkie" chip
                chip(label: "Wszystkie", icon: "tray.full", isActive: selectedFolderId == nil) {
                    selectedFolderId = nil
                }
                ForEach(folderStore.folders) { folder in
                    folderChip(folder)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Theme.surface.opacity(0.5))
    }

    private func folderChip(_ folder: Folder) -> some View {
        let isActive = selectedFolderId == folder.id
        return Button {
            selectedFolderId = (selectedFolderId == folder.id) ? nil : folder.id
        } label: {
            HStack(spacing: 4) {
                Text(folder.emoji)
                    .font(.caption)
                Text(folder.name)
                    .font(.caption.bold())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isActive ? folder.color : Theme.surface)
            .foregroundColor(isActive ? .white : Theme.textPrimary)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(isActive ? Color.clear : folder.color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var tagFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "Wszystkie" chip
                chip(label: "Wszystkie", icon: "tray.full", isActive: selectedTag == nil) {
                    selectedTag = nil
                }
                ForEach(store.allTags, id: \.self) { tag in
                    chip(label: tag, icon: "tag", isActive: selectedTag == tag) {
                        selectedTag = (selectedTag == tag) ? nil : tag
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Theme.surface.opacity(0.5))
    }

    private func chip(label: String, icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(label)
                    .font(.caption.bold())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isActive ? Theme.gold : Theme.surface)
            .foregroundColor(isActive ? .white : Theme.textPrimary)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(isActive ? Color.clear : Theme.gold.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func conversationButton(_ conv: Conversation) -> some View {
        Button {
            selectConversation(conv)
        } label: {
            ConversationRow(
                conversation: conv,
                isSelected: conv.id == store.currentConversationId,
                selectedTag: selectedTag
            )
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .leading) {
            Button {
                store.togglePin(conv)
            } label: {
                Label(conv.isPinned ? "Odepnij" : "Przypnij",
                      systemImage: conv.isPinned ? "pin.slash" : "pin")
            }
            .tint(Theme.gold)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                store.delete(conv)
            } label: {
                Label("Usuń", systemImage: "trash")
            }
            Button {
                editingTagsFor = conv
            } label: {
                Label("Tagi", systemImage: "tag")
            }
            .tint(Theme.blue)
        }
        .contextMenu {
            Button {
                store.togglePin(conv)
            } label: {
                Label(conv.isPinned ? "Odepnij" : "Przypnij",
                      systemImage: conv.isPinned ? "pin.slash" : "pin")
            }
            Button {
                editingTagsFor = conv
            } label: {
                Label("Edytuj tagi", systemImage: "tag")
            }
            Button {
                movingToFolderFor = conv
            } label: {
                Label("Przenieś do folderu", systemImage: "folder")
            }
            Divider()
            Button(role: .destructive) {
                store.delete(conv)
            } label: {
                Label("Usuń", systemImage: "trash")
            }
        }
    }

    private func searchResultButton(_ result: SearchResult) -> some View {
        Button {
            selectConversation(result.conversation)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    if result.conversation.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundColor(Theme.gold)
                    }
                    Text(result.conversation.title)
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                }
                if !result.titleMatch {
                    // Pokaż snippet z matchem
                    ForEach(result.matchedMessages.prefix(2)) { msg in
                        searchSnippet(msg.content, query: searchText)
                    }
                }
                if !result.conversation.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(result.conversation.tags.prefix(3), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.blue.opacity(0.15))
                                .foregroundColor(Theme.blue)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    /// Snippet z podświetlonym matchem (dla search)
    private func searchSnippet(_ content: String, query: String) -> some View {
        let lower = content.lowercased()
        let q = query.lowercased()
        guard let range = lower.range(of: q) else {
            return Text(content.prefix(120))
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .lineLimit(2)
        }
        // 40 znaków przed + match + 40 po
        let start = lower.index(range.lowerBound, offsetBy: -40, limitedBy: lower.startIndex) ?? lower.startIndex
        let end = lower.index(range.upperBound, offsetBy: 40, limitedBy: lower.endIndex) ?? lower.endIndex
        let prefix = start == lower.startIndex ? "" : "…"
        let suffix = end == lower.endIndex ? "" : "…"
        let nsContent = content as NSString
        let matchStart = lower.distance(from: lower.startIndex, to: range.lowerBound)
        let matchLen = q.count
        let beforeText = nsContent.substring(with: NSRange(location: start == lower.startIndex ? matchStart : 40, length: start == lower.startIndex ? matchStart : 40))
        let matchText = nsContent.substring(with: NSRange(location: matchStart, length: matchLen))
        let afterText = nsContent.substring(with: NSRange(location: matchStart + matchLen, length: min(40, content.count - matchStart - matchLen)))

        return (Text(prefix).foregroundColor(Theme.textSecondary)
            + Text(beforeText).foregroundColor(Theme.textSecondary)
            + Text(matchText).foregroundColor(Theme.gold).bold()
            + Text(afterText).foregroundColor(Theme.textSecondary)
            + Text(suffix).foregroundColor(Theme.textSecondary))
            .font(.caption)
            .lineLimit(2)
    }

    // MARK: - Helpers

    private var filteredConversations: [Conversation] {
        var convs = store.conversations
        // Filtrowanie po folderze
        if let folderId = selectedFolderId {
            convs = convs.filter { $0.folderId == folderId }
        }
        // Filtrowanie po tagu
        if let tag = selectedTag {
            convs = convs.filter { $0.tags.contains(tag) }
        }
        // Sortowanie: pinned first, potem updatedAt
        return convs.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: emptyIcon)
                .font(.system(size: 56))
                .foregroundStyle(Theme.textSecondary)
            Text(emptyTitle)
                .font(.headline)
                .foregroundColor(Theme.textSecondary)
            if !searchText.isEmpty {
                Text("Dla \"\(searchText)\"")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary.opacity(0.7))
            } else if selectedTag != nil {
                Text("Tag: #\(selectedTag ?? "")")
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

    private var emptyIcon: String {
        if !searchText.isEmpty { return "magnifyingglass" }
        if selectedTag != nil { return "tag.slash" }
        return "tray"
    }

    private var emptyTitle: String {
        if !searchText.isEmpty { return "Brak wyników" }
        if selectedTag != nil { return "Brak rozmów z tym tagiem" }
        return "Brak rozmów"
    }

    private func selectConversation(_ conv: Conversation) {
        store.currentConversationId = conv.id
        onSelect?()
        dismiss()
    }

    private func deleteConversations(at offsets: IndexSet) {
        let toDelete = offsets.map { filteredConversations[$0] }
        for conv in toDelete {
            store.delete(conv)
        }
    }
}

// MARK: - Row

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

                // Tagi + folder badge
                HStack(spacing: 4) {
                    // Folder badge (jeśli jest)
                    if let folder = folder {
                        HStack(spacing: 3) {
                            Text(folder.emoji)
                                .font(.caption2)
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
                    // Tagi
                    ForEach(conversation.tags.prefix(folder == nil ? 3 : 2), id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(
                                selectedTag == tag
                                ? Theme.gold.opacity(0.3)
                                : Theme.blue.opacity(0.15)
                            )
                            .foregroundColor(selectedTag == tag ? Theme.textPrimary : Theme.blue)
                            .clipShape(Capsule())
                    }
                    if conversation.tags.count > 3 {
                        Text("+\(conversation.tags.count - 3)")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
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

    private var initials: String {
        let words = conversation.title.split(separator: " ")
        if let first = words.first?.first {
            return String(first).uppercased()
        }
        return "💬"
    }
}

//
//  HistoryView.swift
//  MiniChat
//
//  Lista konwersacji z: search, pin, tag/folder filter, sortowanie.
//  Sub-komponenty wydzielone do Views/History/.
//

import SwiftUI

struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: ConversationStore
    @StateObject private var folderStore = FolderStore.shared
    @State private var searchText: String = ""
    @State private var exportTarget: ExportTarget?
    @State private var showStats: Bool = false
    @State private var selectedTag: String? = nil
    @State private var selectedFolderId: UUID? = nil
    @State private var editingTagsFor: Conversation?
    @State private var showFolders: Bool = false
    @State private var movingToFolderFor: Conversation?
    @State private var showDeleteAllConfirmation: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if folderStore.folders.count > 1 {
                    FolderFilterBar(folders: folderStore.folders, selectedFolderId: $selectedFolderId)
                }
                if !store.allTags.isEmpty {
                    TagFilterBar(tags: store.allTags, selectedTag: $selectedTag)
                }

                content
            }
            .navigationTitle("Historia")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(text: $searchText, prompt: "Szukaj w rozmowach")
            .toolbar { toolbarContent }
            .confirmationDialog(
                "Usunąć wszystkie rozmowy?",
                isPresented: $showDeleteAllConfirmation,
                titleVisibility: .visible
            ) {
                Button("Usuń wszystkie", role: .destructive) { store.deleteAll() }
                Button("Anuluj", role: .cancel) {}
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
            .sheet(item: $exportTarget) { target in
                ShareSheet(items: [makeTempMarkdownFile(body: target.markdownBody, filename: target.suggestedFilename)])
            }
            .sheet(isPresented: $showStats) {
                StatsView()
            }
        }
    }

    private func makeTempMarkdownFile(body: String, filename: String) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(filename).md")
        try? body.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    @ViewBuilder
    private var content: some View {
        if searchText.isEmpty {
            conversationsList
        } else {
            searchResultsList
        }
    }

    private var conversationsList: some View {
        Group {
            if filteredConversations.isEmpty {
                HistoryEmptyState(searchText: searchText, selectedTag: selectedTag)
            } else {
                List {
                    let pinned = filteredConversations.filter { $0.isPinned }
                    let unpinned = filteredConversations.filter { !$0.isPinned }
                    if !pinned.isEmpty {
                        Section {
                            ForEach(pinned) { conv in conversationRow(for: conv) }
                        } header: {
                            Label("Przypięte", systemImage: "pin.fill")
                                .font(.caption.bold())
                                .foregroundColor(Theme.gold)
                        }
                    }
                    if !unpinned.isEmpty {
                        Section {
                            ForEach(unpinned) { conv in conversationRow(for: conv) }
                                .onDelete(perform: deleteConversations)
                        } header: {
                            if !pinned.isEmpty {
                                Text("Wszystkie rozmowy").font(.caption.bold())
                            }
                        }
                    }
                }
            }
        }
    }

    private var searchResultsList: some View {
        let results = store.search(query: searchText)
        return Group {
            if results.isEmpty {
                HistoryEmptyState(searchText: searchText, selectedTag: selectedTag)
            } else {
                List {
                    ForEach(results) { result in searchResultRow(result) }
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
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
                    if !store.conversations.isEmpty {
                        Button {
                            showStats = true
                        } label: {
                            Label("Statystyki", systemImage: "chart.bar.xaxis")
                        }
                    }
                    Divider()
                    Button(role: .destructive) {
                        showDeleteAllConfirmation = true
                    } label: {
                        Label("Usuń wszystkie", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    private func conversationRow(for conv: Conversation) -> some View {
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
        .contextMenu { conversationContextMenu(conv) }
    }

    @ViewBuilder
    private func conversationContextMenu(_ conv: Conversation) -> some View {
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
        Button {
            exportTarget = ExportTarget(conversation: conv)
        } label: {
            Label("Eksportuj jako Markdown", systemImage: "square.and.arrow.up")
        }
        Divider()
        Button(role: .destructive) {
            store.delete(conv)
        } label: {
            Label("Usuń", systemImage: "trash")
        }
    }

    private func searchResultRow(_ result: SearchResult) -> some View {
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
                    ForEach(result.matchedMessages.prefix(2)) { msg in
                        SearchSnippetView(content: msg.content, query: searchText)
                    }
                }
                if !result.conversation.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(result.conversation.tags.prefix(3), id: \.self) { tag in
                            TagPill(tag: tag, isHighlighted: false)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var filteredConversations: [Conversation] {
        var convs = store.conversations
        if let folderId = selectedFolderId {
            convs = convs.filter { $0.folderId == folderId }
        }
        if let tag = selectedTag {
            convs = convs.filter { $0.tags.contains(tag) }
        }
        return convs.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private func selectConversation(_ conv: Conversation) {
        store.currentConversationId = conv.id
        dismiss()
    }

    private func deleteConversations(at offsets: IndexSet) {
        let toDelete = offsets.map { filteredConversations[$0] }
        for conv in toDelete {
            store.delete(conv)
        }
    }
}

/// Wrapper przechowujacy kontekst eksportu - potrzebny zeby uzyc jako `.sheet(item:)`.
struct ExportTarget: Identifiable {
    let id = UUID()
    let conversation: Conversation

    var markdownBody: String {
        MarkdownExporter.render(conversation)
    }

    var suggestedFilename: String {
        MarkdownExporter.suggestedFilename(for: conversation)
    }
}

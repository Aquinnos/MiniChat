//
//  FoldersView.swift
//  MiniChat
//
//  Zarządzanie folderami - lista, tworzenie, edycja, usuwanie.
//

import SwiftUI

struct FoldersView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var folderStore: FolderStore
    @EnvironmentObject private var conversationStore: ConversationStore
    @State private var editingFolder: Folder?
    @State private var showCreate: Bool = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(folderStore.folders) { folder in
                        Button {
                            // Można dodać akcję "Pokaż konwersacje w tym folderze"
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(folder.color)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Text(folder.emoji)
                                            .font(.system(size: 16))
                                    )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(folder.name)
                                        .font(.body.bold())
                                        .foregroundColor(Theme.textPrimary)
                                    Text("\(conversationStore.conversations(in: folder.id).count) rozmów")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                // Przenieś konwersacje z tego folderu do "Bez folderu"
                                let convs = conversationStore.conversations(in: folder.id)
                                for conv in convs {
                                    conversationStore.setFolder(nil, for: conv)
                                }
                                folderStore.remove(folder)
                            } label: {
                                Label("Usuń", systemImage: "trash")
                            }
                            Button {
                                editingFolder = folder
                            } label: {
                                Label("Edytuj", systemImage: "pencil")
                            }
                            .tint(Theme.blue)
                        }
                    }
                } header: {
                    Text("Twoje foldery")
                } footer: {
                    Text("Foldery pomagają grupować rozmowy. Usunięcie folderu przenosi konwersacje z powrotem do 'Bez folderu'.")
                        .font(.caption)
                }
            }
            .navigationTitle("Foldery")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Gotowe") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $editingFolder) { folder in
                FolderEditorView(folder: folder, isNew: false)
            }
            .sheet(isPresented: $showCreate) {
                FolderEditorView(folder: Folder(name: ""), isNew: true)
            }
        }
    }
}

// MARK: - Editor

struct FolderEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var folderStore = FolderStore.shared

    @State var folder: Folder
    let isNew: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Nazwa i ikona") {
                    HStack {
                        TextField("Emoji", text: $folder.emoji)
                            .frame(width: 60)
                            .multilineTextAlignment(.center)
                            .font(.title)
                        TextField("Nazwa folderu", text: $folder.name)
                    }
                }

                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                        ForEach(FolderColor.presets, id: \.self) { hex in
                            colorChip(hex)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Kolor")
                } footer: {
                    Text("Wybierz kolor - foldery będą miały kolorowe tło w historii.")
                        .font(.caption)
                }
            }
            .navigationTitle(isNew ? "Nowy folder" : "Edytuj folder")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zapisz") {
                        if isNew {
                            folderStore.add(folder)
                        } else {
                            folderStore.update(folder)
                        }
                        dismiss()
                    }
                    .disabled(folder.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func colorChip(_ hex: String) -> some View {
        let color = Color(hex: hex) ?? Theme.gold
        return Button {
            folder.colorHex = hex
        } label: {
            Circle()
                .fill(color)
                .frame(width: 36, height: 36)
                .overlay(
                    Circle()
                        .stroke(folder.colorHex == hex ? Color.white : Color.clear, lineWidth: 3)
                )
                .shadow(color: folder.colorHex == hex ? color.opacity(0.5) : .clear, radius: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Folder picker (do ustawiania folderu konwersacji)

struct FolderPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var folderStore = FolderStore.shared
    let conversation: Conversation
    var onSelect: (UUID?) -> Void

    var body: some View {
        NavigationStack {
            List {
                Button {
                    onSelect(nil)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "tray")
                            .foregroundColor(Theme.textSecondary)
                        Text("Bez folderu")
                            .foregroundColor(Theme.textPrimary)
                        Spacer()
                        if conversation.folderId == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(Theme.gold)
                        }
                    }
                }

                ForEach(folderStore.folders) { folder in
                    Button {
                        onSelect(folder.id)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(folder.color)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Text(folder.emoji)
                                        .font(.system(size: 14))
                                )
                            Text(folder.name)
                                .foregroundColor(Theme.textPrimary)
                            Spacer()
                            if conversation.folderId == folder.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Theme.gold)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Przenieś do folderu")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { dismiss() }
                }
            }
        }
    }
}

//
//  RenameSheet.swift
//  MiniChat
//
//  Edycja tytułu konwersacji - TextField z zapisem do ConversationStore.
//

import SwiftUI

struct RenameSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: ConversationStore

    let conversation: Conversation
    @State private var title: String = ""
    @FocusState private var titleFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Tytuł rozmowy", text: $title)
                        .focused($titleFocused)
                        .submitLabel(.done)
                        .onSubmit { save() }
                } footer: {
                    Text("Zmiana tytułu nie zmienia treści wiadomości.")
                        .font(.caption)
                }
            }
            .navigationTitle("Zmień nazwę")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zapisz") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                title = conversation.title
                titleFocused = true
            }
        }
    }

    private func save() {
        store.rename(conversation, to: title)
        dismiss()
    }
}

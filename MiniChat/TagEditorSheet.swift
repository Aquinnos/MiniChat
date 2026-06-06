//
//  TagEditorSheet.swift
//  MiniChat
//
//  Edytor tagów dla wybranej konwersacji - dodaj/usuń tagi.
//

import SwiftUI

struct TagEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: ConversationStore

    let conversation: Conversation
    @State private var newTag: String = ""
    @FocusState private var newTagFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("np. swiftui, praca, pomysły", text: $newTag)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($newTagFocused)
                            .onSubmit { addTag() }
                        Button {
                            addTag()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(Theme.blue)
                        }
                        .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("Dodaj tag")
                } footer: {
                    Text("Tagi pomagają organizować rozmowy. Będą widoczne w historii i możesz filtrować po nich.")
                        .font(.caption)
                }

                if !conversation.tags.isEmpty {
                    Section("Aktualne tagi") {
                        ForEach(conversation.tags, id: \.self) { tag in
                            HStack {
                                Image(systemName: "tag.fill")
                                    .foregroundColor(Theme.gold)
                                Text(tag)
                                    .font(.body)
                                Spacer()
                                Button {
                                    store.removeTag(tag, from: conversation)
                                    // Hmm - tu nie aktualizujemy local state, bo sheet odświeża z store
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } else {
                    Section {
                        Text("Brak tagów")
                            .foregroundStyle(.secondary)
                    }
                }

                if !store.allTags.filter({ !conversation.tags.contains($0) }).isEmpty {
                    Section("Sugerowane") {
                        let suggested = store.allTags.filter { !conversation.tags.contains($0) }
                        FlowLayout(spacing: 6) {
                            ForEach(suggested, id: \.self) { tag in
                                Button {
                                    store.addTag(tag, to: conversation)
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus")
                                            .font(.caption2)
                                        Text(tag)
                                            .font(.caption.bold())
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Theme.surface)
                                    .foregroundColor(Theme.textPrimary)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule().stroke(Theme.gold.opacity(0.3), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Tagi")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gotowe") { dismiss() }
                }
            }
            .onAppear {
                newTagFocused = true
            }
        }
    }

    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        store.addTag(trimmed, to: conversation)
        newTag = ""
    }
}

// MARK: - Flow layout dla chipów

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(subviews: subviews, in: proposal.width ?? 0)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(subviews: subviews, in: bounds.width)
        for (i, frame) in result.frames.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                              proposal: ProposedViewSize(frame.size))
        }
    }

    private func layout(subviews: Subviews, in width: CGFloat) -> (frames: [CGRect], size: CGSize) {
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxWidth: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxWidth = max(maxWidth, x)
        }
        return (frames, CGSize(width: maxWidth, height: y + rowHeight))
    }
}

//
//  EditMessageView.swift
//  MiniChat
//
//  Sheet do edycji wybranej wiadomości użytkownika.
//

import SwiftUI
import PhotosUI

struct EditMessageView: View {
    @Environment(\.dismiss) private var dismiss
    let originalMessage: Message
    let onSave: (String, [Attachment]) -> Void

    @State private var text: String = ""
    @State private var attachments: [Attachment] = []
    @State private var showFilePicker: Bool = false
    @State private var photoPickerItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            Form {
                Section("Wiadomość") {
                    TextField("Twoja wiadomość", text: $text, axis: .vertical)
                        .lineLimit(3...10)
                }

                if !attachments.isEmpty {
                    Section("Załączniki") {
                        ForEach(attachments) { att in
                            HStack {
                                Image(systemName: att.isImage ? "photo" : "doc")
                                Text(att.fileName)
                                Spacer()
                                Button {
                                    attachments.removeAll(where: { $0.id == att.id })
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                }

                Section {
                    PhotosPicker(selection: $photoPickerItem, matching: .images, photoLibrary: .shared()) {
                        Label("Dodaj zdjęcie", systemImage: "photo")
                    }
                    Button {
                        showFilePicker = true
                    } label: {
                        Label("Dodaj plik", systemImage: "paperclip")
                    }
                }
            }
            .navigationTitle("Edytuj wiadomość")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Regeneruj") {
                        onSave(text, attachments)
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachments.isEmpty)
                }
            }
            .sheet(isPresented: $showFilePicker) {
                DocumentPicker(allowedTypes: [.image, .pdf, .plainText, .json, .data, .sourceCode, .text]) { url in
                    if let att = AttachmentBuilder.build(from: url) {
                        attachments.append(att)
                    }
                }
            }
            .onChange(of: photoPickerItem) { _, newItem in
                Task {
                    guard let newItem else { return }
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        let att = Attachment(
                            type: .image,
                            mimeType: "image/jpeg",
                            fileName: "image_\(Int(Date().timeIntervalSince1970)).jpg",
                            base64Data: data.base64EncodedString(),
                            textContent: nil
                        )
                        attachments.append(att)
                    }
                    photoPickerItem = nil
                }
            }
        }
        .onAppear {
            text = originalMessage.content
            attachments = originalMessage.attachments
        }
    }
}

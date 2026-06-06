//
//  ImageGenSheet.swift
//  MiniChat
//
//  Sheet do ręcznego generowania obrazów - bez proszenia modelu.
//

import SwiftUI

struct ImageGenSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onGenerate: (String, String) async -> Void  // (prompt, aspectRatio) -> Void

    @State private var prompt: String = ""
    @State private var aspectRatio: String = "1:1"
    @State private var isGenerating: Bool = false

    private let aspectRatios: [(String, String)] = [
        ("1:1", "Kwadrat"),
        ("16:9", "Pejzaż (tapeta)"),
        ("9:16", "Portret (telefon)"),
        ("3:2", "Zdjęcie"),
        ("4:3", "Klasyczne")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Opisz obraz, który chcesz wygenerować", text: $prompt, axis: .vertical)
                        .lineLimit(3...8)
                } header: {
                    Text("Prompt")
                } footer: {
                    Text("W języku angielskim będzie lepsza jakość. Bądź konkretny: postać, styl, oświetlenie, kolory.")
                        .font(.caption)
                }

                Section("Proporcje") {
                    Picker("Aspect Ratio", selection: $aspectRatio) {
                        ForEach(aspectRatios, id: \.0) { ratio in
                            Text("\(ratio.0) — \(ratio.1)").tag(ratio.0)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section {
                    Button {
                        Task { await generate() }
                    } label: {
                        HStack {
                            if isGenerating {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isGenerating ? "Generuję..." : "🎨 Generuj obraz")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)
                }
            }
            .navigationTitle("Generuj obraz")
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

    private func generate() async {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else { return }
        isGenerating = true
        await onGenerate(trimmedPrompt, aspectRatio)
        isGenerating = false
        dismiss()
    }
}

//
//  ModelPickerView.swift
//  MiniChat
//
//  Wybór modelu AI z listy (sheet, bo confirmationDialog ogranicza do 3 akcji).
//

import SwiftUI

struct ModelPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedModel: MiniMaxModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(MiniMaxModel.allCases) { model in
                        Button {
                            selectedModel = model
                            dismiss()
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: iconFor(model))
                                    .font(.title3)
                                    .foregroundColor(colorFor(model))
                                    .frame(width: 32)
                                    .padding(.top, 2)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(model.displayName)
                                            .font(.headline)
                                            .foregroundColor(Theme.textPrimary)
                                        if model.isReasoning {
                                            Text("[reasoning]")
                                                .font(.caption2)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 1)
                                                .background(Theme.gold.opacity(0.15))
                                                .foregroundColor(Theme.gold)
                                                .clipShape(Capsule())
                                        }
                                        Spacer()
                                        if model == selectedModel {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(Theme.blue)
                                        }
                                    }
                                    Text(model.description)
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Model AI")
                } footer: {
                    Text("Modele oznaczone [reasoning] to reasoning models — najpierw pokażą swoje rozważania, a potem odpowiedź.")
                        .font(.caption)
                }
            }
            .navigationTitle("Wybierz model")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gotowe") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func iconFor(_ model: MiniMaxModel) -> String {
        switch model {
        case .m3: return "crown.fill"
        case .m27: return "star.fill"
        case .m27Highspeed: return "bolt.fill"
        case .m2: return "checkmark.seal.fill"
        case .m2her: return "person.2.fill"
        }
    }

    private func colorFor(_ model: MiniMaxModel) -> Color {
        switch model {
        case .m3: return Theme.gold
        case .m27: return Theme.blue
        case .m27Highspeed: return Color.orange
        case .m2: return Color.green
        case .m2her: return Color.purple
        }
    }
}

#Preview {
    @Previewable @State var model: MiniMaxModel = .m27
    return ModelPickerView(selectedModel: $model)
}

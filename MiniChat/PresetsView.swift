//
//  PresetsView.swift
//  MiniChat
//
//  UI do zarządzania Custom Presets - lista, edycja, tworzenie.
//

import SwiftUI

struct PresetsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var presetStore = PresetStore.shared
    @State private var editingPreset: Preset?
    @State private var showCreate: Bool = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    // Domyślny (bez system promptu)
                    Button {
                        presetStore.selectPreset(nil)
                    } label: {
                        HStack {
                            Text("💬")
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Domyślny")
                                    .font(.body.bold())
                                    .foregroundColor(Theme.textPrimary)
                                Text("Bez dodatkowych instrukcji - model działa standardowo")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if presetStore.selectedPresetId == nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Theme.gold)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                Section("Twoje presety") {
                    ForEach(presetStore.customPresets) { preset in
                        Button {
                            presetStore.selectPreset(preset)
                        } label: {
                            HStack(spacing: 12) {
                                Text(preset.emoji)
                                    .font(.title2)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(preset.name)
                                        .font(.body.bold())
                                        .foregroundColor(Theme.textPrimary)
                                    HStack(spacing: 4) {
                                        Text(preset.model.displayName)
                                            .font(.caption2)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1)
                                            .background(Theme.blue.opacity(0.15))
                                            .foregroundColor(Theme.blue)
                                            .clipShape(Capsule())
                                        Text("🌡 \(String(format: "%.1f", preset.temperature))")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        if !preset.allowedTools.isEmpty {
                                            Text("·")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            Text("\(preset.allowedTools.count) narzędzi")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                Spacer()
                                if presetStore.selectedPresetId == preset.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Theme.gold)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                presetStore.remove(preset)
                            } label: {
                                Label("Usuń", systemImage: "trash")
                            }
                            Button {
                                editingPreset = preset
                            } label: {
                                Label("Edytuj", systemImage: "pencil")
                            }
                            .tint(Theme.blue)
                            Button {
                                let copy = presetStore.duplicate(preset)
                                presetStore.add(copy)
                            } label: {
                                Label("Duplikuj", systemImage: "doc.on.doc")
                            }
                            .tint(Theme.gold)
                        }
                    }
                }
            }
            .navigationTitle("Presety")
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
            .sheet(item: $editingPreset) { preset in
                PresetEditorView(preset: preset, isNew: false)
            }
            .sheet(isPresented: $showCreate) {
                PresetEditorView(preset: Preset(name: "Nowy preset"), isNew: true)
            }
        }
    }
}

// MARK: - Editor

struct PresetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var presetStore = PresetStore.shared

    @State var preset: Preset
    let isNew: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Nazwa i ikona") {
                    HStack {
                        TextField("Emoji", text: $preset.emoji)
                            .frame(width: 60)
                            .multilineTextAlignment(.center)
                            .font(.title)
                        TextField("Nazwa", text: $preset.name)
                    }
                }

                Section {
                    TextEditor(text: $preset.systemPrompt)
                        .frame(minHeight: 120)
                        .font(.body)
                } header: {
                    Text("System Prompt")
                } footer: {
                    Text("Instrukcje dla modelu - kim jest, jak ma się zachowywać, w jakim formacie odpowiadać. Im konkretniej, tym lepiej.")
                        .font(.caption)
                }

                Section("Model") {
                    Picker("Model", selection: $preset.model) {
                        ForEach(MiniMaxModel.allCases) { model in
                            Text(model.displayName).tag(model)
                        }
                    }
                }

                Section {
                    HStack {
                        Image(systemName: "thermometer")
                        Slider(value: $preset.temperature, in: 0...2, step: 0.1)
                        Text(String(format: "%.1f", preset.temperature))
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 30, alignment: .trailing)
                    }
                } header: {
                    Text("Temperature")
                } footer: {
                    Text("0 = precyzyjny i powtarzalny · 1 = zbalansowany · 2 = kreatywny i losowy")
                        .font(.caption)
                }

                Section("Dostępne narzędzia") {
                    ForEach(ToolName.allCases, id: \.self) { tool in
                        Toggle(isOn: Binding(
                            get: { preset.allowedTools.contains(tool) },
                            set: { isOn in
                                if isOn {
                                    preset.allowedTools.insert(tool)
                                } else {
                                    preset.allowedTools.remove(tool)
                                }
                            }
                        )) {
                            Label(tool.displayName, systemImage: tool.icon)
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "Nowy preset" : "Edytuj preset")
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
                            presetStore.add(preset)
                        } else {
                            presetStore.update(preset)
                        }
                        dismiss()
                    }
                    .disabled(preset.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#Preview {
    PresetsView()
}

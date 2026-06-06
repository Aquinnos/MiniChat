//
//  ToolsAccessSheet.swift
//  MiniChat
//
//  Lista dostępnych narzędzi z ich statusem ON/OFF.
//

import SwiftUI

struct ToolsAccessSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var modelStore: ModelStore
    @StateObject private var presetStore = PresetStore.shared
    @AppStorage("webSearchEnabled") private var webSearchEnabled: Bool = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Model może wywoływać te narzędzia w trakcie rozmowy. Zmiany dotyczą aktywnego presetu.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    ForEach(ToolName.allCases, id: \.self) { tool in
                        toolRow(tool)
                    }
                } header: {
                    Text("Dostępne narzędzia")
                } footer: {
                    if let preset = presetStore.selectedPreset {
                        Text("Aktywny preset: \(preset.emoji) \(preset.name)")
                            .font(.caption)
                    } else {
                        Text("Aktywny preset: Domyślny (M3 = wszystkie tools)")
                            .font(.caption)
                    }
                }

                Section {
                    Button {
                        webSearchEnabled = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack {
                            Image(systemName: "magnifyingglass.circle.fill")
                                .foregroundColor(Theme.blue)
                            Text("Włącz web search (globalnie)")
                            Spacer()
                            if webSearchEnabled {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Theme.gold)
                            }
                        }
                    }
                    Button {
                        webSearchEnabled = false
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack {
                            Image(systemName: "magnifyingglass.circle")
                                .foregroundColor(Theme.textSecondary)
                            Text("Wyłącz web search (globalnie)")
                            Spacer()
                            if !webSearchEnabled {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Theme.gold)
                            }
                        }
                    }
                } header: {
                    Text("Szybkie akcje")
                } footer: {
                    Text("Te ustawienia działają dla wszystkich rozmów bez wybranego presetu. Dla presetów zdefiniowane osobno.")
                        .font(.caption)
                }
            }
            .navigationTitle("Tools access")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gotowe") { dismiss() }
                }
            }
        }
    }

    private func toolRow(_ tool: ToolName) -> some View {
        let enabled = isEnabled(tool)
        return Button {
            toggleTool(tool)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: tool.icon)
                    .font(.title3)
                    .foregroundColor(enabled ? Theme.gold : Theme.textSecondary)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(tool.displayName)
                        .font(.body)
                        .foregroundColor(Theme.textPrimary)
                    Text(toolDescription(tool))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if enabled {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.gold)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(Theme.textSecondary.opacity(0.4))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func isEnabled(_ tool: ToolName) -> Bool {
        if let preset = presetStore.selectedPreset {
            return preset.allowedTools.contains(tool)
        }
        // Bez presetu
        if tool == .webSearch {
            return webSearchEnabled
        }
        return modelStore.selectedModel == .m3
    }

    private func toggleTool(_ tool: ToolName) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if var preset = presetStore.selectedPreset {
            // Toggle w presecie
            if preset.allowedTools.contains(tool) {
                preset.allowedTools.remove(tool)
            } else {
                preset.allowedTools.insert(tool)
            }
            presetStore.update(preset)
        } else if tool == .webSearch {
            // Bez presetu - globalny toggle (przez @AppStorage)
            webSearchEnabled.toggle()
        }
        // Inne tools bez presetu - nic nie rób (wymaga presetu)
    }

    private func toolDescription(_ tool: ToolName) -> String {
        switch tool {
        case .webSearch: return "Szukaj aktualnych informacji w internecie"
        case .generateImage: return "Twórz obrazy z opisu tekstowego"
        case .getCurrentTime: return "Sprawdź aktualną datę i godzinę"
        case .readFile: return "Czytaj treść załączonych plików"
        }
    }
}

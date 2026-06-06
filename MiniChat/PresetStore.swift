//
//  PresetStore.swift
//  MiniChat
//
//  Persistence Custom Presets w UserDefaults + pierwszy setup z wbudowanymi.
//

import Foundation
import Combine

@MainActor
final class PresetStore: ObservableObject {
    static let shared = PresetStore()

    @Published private(set) var customPresets: [Preset] = []
    @Published var selectedPresetId: UUID? = nil  // nil = domyślny (bez system promptu)

    private let customKey = "customPresets_v1"
    private let selectedKey = "selectedPresetId"

    init() {
        load()
        // Pierwszy setup: jeśli brak custom presets, wczytaj wbudowane jako przykłady
        if customPresets.isEmpty {
            customPresets = BuiltInPresets.all
            save()
        }
    }

    /// Aktywny preset (lub nil gdy wybrano "Domyślny")
    var selectedPreset: Preset? {
        guard let id = selectedPresetId else { return nil }
        return customPresets.first { $0.id == id }
    }

    /// Czy model powinien używać tools (bierzemy z preseta jeśli wybrany, inaczej z ustawień)
    func shouldUseTools(for model: MiniMaxModel) -> Bool {
        if let preset = selectedPreset {
            return !preset.allowedTools.isEmpty
        }
        return model == .m3
    }

    /// Zwraca listę tools w formacie API (OpenAI compatible)
    func apiTools() -> [[String: Any]]? {
        guard let preset = selectedPreset, !preset.allowedTools.isEmpty else { return nil }
        var allTools: [[String: Any]] = []
        for tool in preset.allowedTools {
            switch tool {
            case .webSearch: allTools.append(MiniMaxTool.webSearch)
            case .generateImage: allTools.append(MiniMaxTool.generateImage)
            case .getCurrentTime: allTools.append(MiniMaxTool.getCurrentTime)
            case .readFile: allTools.append(MiniMaxTool.readFile)
            }
        }
        return allTools.isEmpty ? nil : allTools
    }

    // MARK: - CRUD

    func add(_ preset: Preset) {
        customPresets.append(preset)
        save()
    }

    func update(_ preset: Preset) {
        if let idx = customPresets.firstIndex(where: { $0.id == preset.id }) {
            customPresets[idx] = preset
            save()
        }
    }

    func remove(_ preset: Preset) {
        customPresets.removeAll { $0.id == preset.id }
        if selectedPresetId == preset.id {
            selectedPresetId = nil
        }
        save()
    }

    func selectPreset(_ preset: Preset?) {
        selectedPresetId = preset?.id
        UserDefaults.standard.set(selectedPresetId?.uuidString, forKey: selectedKey)
    }

    /// Duplikuj preset (jako baza do edycji)
    func duplicate(_ preset: Preset) -> Preset {
        var copy = preset
        copy = Preset(
            id: UUID(),
            name: preset.name + " (kopia)",
            emoji: preset.emoji,
            systemPrompt: preset.systemPrompt,
            allowedTools: preset.allowedTools,
            model: preset.model,
            temperature: preset.temperature
        )
        return copy
    }

    // MARK: - Persistence

    private func load() {
        if let data = UserDefaults.standard.data(forKey: customKey),
           let decoded = try? JSONDecoder().decode([Preset].self, from: data) {
            customPresets = decoded
        }
        if let idString = UserDefaults.standard.string(forKey: selectedKey),
           let id = UUID(uuidString: idString) {
            selectedPresetId = id
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(customPresets) {
            UserDefaults.standard.set(data, forKey: customKey)
        }
    }
}

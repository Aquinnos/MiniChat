//
//  FolderStore.swift
//  MiniChat
//
//  Persistence folderów w UserDefaults + metody CRUD + assign to conversation.
//

import Foundation
import Combine

@MainActor
final class FolderStore: ObservableObject {
    static let shared = FolderStore()

    @Published private(set) var folders: [Folder] = []

    private let key = "folders_v1"

    init() {
        load()
        // Pierwszy setup: utwórz "Ogólne" jeśli brak
        if folders.isEmpty {
            folders = [
                Folder(name: "Ogólne", emoji: "", colorHex: "#5856D6")
            ]
            save()
        }
    }

    // MARK: - CRUD

    func add(_ folder: Folder) {
        folders.append(folder)
        save()
    }

    func update(_ folder: Folder) {
        if let idx = folders.firstIndex(where: { $0.id == folder.id }) {
            folders[idx] = folder
            save()
        }
    }

    func remove(_ folder: Folder) {
        folders.removeAll { $0.id == folder.id }
        save()
    }

    func folder(id: UUID) -> Folder? {
        folders.first { $0.id == id }
    }

    // MARK: - Persistence

    private func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Folder].self, from: data) {
            folders = decoded
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(folders) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

//
//  ModelStore.swift
//  MiniChat
//
//  Przechowywanie wybranego modelu AI w UserDefaults.
//

import Foundation
import Combine

@MainActor
final class ModelStore: ObservableObject {
    @Published var selectedModel: MiniMaxModel {
        didSet { save() }
    }

    private let key = "selected_model"

    init() {
        if let raw = UserDefaults.standard.string(forKey: key),
           let model = MiniMaxModel(rawValue: raw) {
            self.selectedModel = model
        } else {
            self.selectedModel = .m27
        }
    }

    private func save() {
        UserDefaults.standard.set(selectedModel.rawValue, forKey: key)
    }
}

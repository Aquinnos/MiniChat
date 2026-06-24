//
//  ChatWelcomeView.swift
//  MiniChat
//
//  Ekran powitalny gdy lista wiadomości jest pusta.
//

import SwiftUI

struct ChatWelcomeView: View {
    @ObservedObject var viewModel: ChatViewModel

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.gold)
                .symbolRenderingMode(.hierarchical)

            Text("Witaj w MiniChat!")
                .font(.title2.bold())
                .foregroundColor(Theme.textPrimary)

            Text("Model: \(viewModel.selectedModel.displayName)\n\(viewModel.selectedModel.description)")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.horizontal, 32)
    }
}

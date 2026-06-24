//
//  ReasoningPanel.swift
//  MiniChat
//
//  Rozwijany panel z rozważaniami modelu (reasoning_content).
//

import SwiftUI

struct ReasoningPanel: View {
    let reasoning: String
    let isThinking: Bool
    let contentEmpty: Bool
    @Binding var expanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expanded.toggle()
                }
            } label: {
                header
            }
            .buttonStyle(.plain)

            if expanded {
                bodyText
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
        }
        .padding(8)
        .background(backgroundShape)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: expanded ? "chevron.down" : "chevron.right")
                .font(.caption2)
            Image(systemName: "brain.head.profile")
                .font(.caption)
            Text("Rozważania")
                .font(.caption.bold())
            if isThinking && contentEmpty {
                Text("• myśli…")
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
        }
        .foregroundColor(Theme.blue)
    }

    private var bodyText: some View {
        Text(reasoning)
            .font(.caption)
            .foregroundColor(Theme.textSecondary)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.blueSoft.opacity(0.3))
            )
            .textSelection(.enabled)
    }

    private var backgroundShape: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Theme.blueSoft.opacity(0.15))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.blue.opacity(0.3), lineWidth: 1)
            )
    }
}

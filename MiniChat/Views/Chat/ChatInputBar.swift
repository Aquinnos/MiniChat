//
//  ChatInputBar.swift
//  MiniChat
//
//  Dolny pasek: menu "+" (photo, file, image gen, web search, folder, tools),
//  pole tekstowe, przycisk wyślij/anuluj.
//

import SwiftUI
import UIKit

struct ChatInputBar: View {
    @ObservedObject var viewModel: ChatViewModel
    @FocusState.Binding var inputFocused: Bool
    @Binding var webSearchEnabled: Bool
    let theme: AppColors
    let onShowPhotoPicker: () -> Void
    let onShowFilePicker: () -> Void
    let onShowImageGen: () -> Void
    let onShowFolderPicker: () -> Void
    let onShowToolsAccess: () -> Void
    let onSend: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            plusMenu
            textField
            sendButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.background)
    }

    private var plusMenu: some View {
        Menu {
            if viewModel.selectedModel.supportsAttachments {
                Button { onShowPhotoPicker() } label: {
                    Label("Dodaj zdjęcie", systemImage: "photo")
                }
                Button { onShowFilePicker() } label: {
                    Label("Dodaj plik", systemImage: "paperclip")
                }
            }
            Button { onShowImageGen() } label: {
                Label("Generuj obraz", systemImage: "paintpalette.fill")
            }
            Divider()
            Toggle(isOn: $webSearchEnabled) {
                Label("Web search", systemImage: "magnifyingglass")
            }
            .onChange(of: webSearchEnabled) { _, newValue in
                UserDefaults.standard.set(newValue, forKey: "webSearchEnabled")
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            Button { onShowFolderPicker() } label: {
                Label("Dodaj do folderu", systemImage: "folder.badge.plus")
            }
            Button { onShowToolsAccess() } label: {
                Label("Tools access", systemImage: "wrench.and.screwdriver")
            }
        } label: {
            if viewModel.isGeneratingImage {
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            } else {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(theme.blue)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isStreaming || viewModel.isGeneratingImage)
    }

    private var textField: some View {
        TextField("Napisz wiadomość…", text: $viewModel.inputText, axis: .vertical)
            .lineLimit(1...5)
            .focused($inputFocused)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Theme.gold.opacity(0.4), lineWidth: 1)
            )
            .disabled(viewModel.isStreaming)
            .onSubmit {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onSend()
            }
    }

    private var sendButton: some View {
        Button {
            if viewModel.isStreaming {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onCancel()
            } else {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onSend()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(canSend ? theme.blue : Color.gray.opacity(0.3))
                    .frame(width: 36, height: 36)
                    .scaleEffect(viewModel.isStreaming ? 0.9 : 1.0)
                    .animation(.spring(response: 0.3), value: viewModel.isStreaming)

                Image(systemName: viewModel.isStreaming ? "stop.fill" : "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .disabled(!canSend && !viewModel.isStreaming)
    }

    private var canSend: Bool {
        let hasText = !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasAttachments = !viewModel.pendingAttachments.isEmpty
        return hasText || hasAttachments
    }
}

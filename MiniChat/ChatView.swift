//
//  ChatView.swift
//  MiniChat
//
//  Główny ekran czatu z sliding side panel (historia), attachments, animowany streaming.
//  Sub-komponenty wydzielone do Views/Chat/.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject private var presetStore = PresetStore.shared
    @EnvironmentObject private var modelStore: ModelStore
    @EnvironmentObject private var store: ConversationStore
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var showSettings = false
    @State private var showHistory = false
    @State private var showModelPicker = false
    @State private var showFilePicker = false
    @State private var showPresets = false
    @State private var showToolsAccess = false
    @State private var showFolderPicker: Bool = false
    @State private var showPhotoPicker: Bool = false
    @State private var showImageGen: Bool = false
    @State private var webSearchEnabled: Bool = UserDefaults.standard.object(forKey: "webSearchEnabled") as? Bool ?? true
    @State private var editingMessage: Message?
    @FocusState private var inputFocused: Bool

    private let edgeSwipeActivationX: CGFloat = 40
    private let edgeSwipeMinDistance: CGFloat = 30
    private let edgeSwipeMinTranslation: CGFloat = 70

    private var theme: AppColors { themeManager.colors(for: colorScheme) }

    var body: some View {
        mainContent
            .simultaneousGesture(edgeSwipeGesture)
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showHistory) { HistoryView() }
            .sheet(isPresented: $showModelPicker) {
                ModelPickerView(selectedModel: $modelStore.selectedModel)
            }
            .sheet(isPresented: $showPresets) { PresetsView() }
            .sheet(isPresented: $showToolsAccess) {
                ToolsAccessSheet()
                    .environmentObject(modelStore)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showFolderPicker) {
                if let conv = viewModel.currentConversation {
                    FolderPickerSheet(conversation: conv) { folderId in
                        store.setFolder(folderId, for: conv)
                    }
                }
            }
            .sheet(item: $editingMessage) { msg in
                EditMessageView(originalMessage: msg) { newContent, newAttachments in
                    Task {
                        await viewModel.editAndRegenerate(
                            messageId: msg.id,
                            newContent: newContent,
                            newAttachments: newAttachments
                        )
                    }
                }
            }
            .sheet(isPresented: $showImageGen) {
                ImageGenSheet { prompt, aspectRatio in
                    await viewModel.generateImageManually(prompt: prompt, aspectRatio: aspectRatio)
                }
            }
            .sheet(isPresented: $showFilePicker) {
                DocumentPicker(allowedTypes: [.image, .pdf, .plainText, .json, .data, .sourceCode, .text]) { url in
                    if let attachment = AttachmentBuilder.build(from: url) {
                        viewModel.addAttachment(attachment)
                    }
                }
            }
            .sheet(isPresented: $showPhotoPicker) {
                PhotoPickerSheet { image in
                    addPhotoAttachment(image)
                }
                .ignoresSafeArea()
            }
            .alert("Błąd", isPresented: .constant(viewModel.errorMessage != nil), presenting: viewModel.errorMessage) { _ in
                Button("OK") { viewModel.clearError() }
            } message: { msg in
                Text(msg)
            }
    }

    // MARK: - Main content

    private var mainContent: some View {
        VStack(spacing: 0) {
            ChatHeader(
                viewModel: viewModel,
                presetStore: presetStore,
                onShowHistory: { showHistory = true },
                onShowModelPicker: { showModelPicker = true },
                onShowPresets: { showPresets = true },
                onStartNewChat: { viewModel.startNewChat() },
                onShowSettings: { showSettings = true }
            )
            Divider().background(theme.gold.opacity(0.3))
            ChatMessagesList(
                viewModel: viewModel,
                onEdit: { msg in editingMessage = msg },
                onDelete: { msg in viewModel.deleteMessage(msg) },
                onRegenerate: { msg in
                    Task { await viewModel.regenerateFromAssistant(msg) }
                },
                onFork: { msg in viewModel.forkMessage(msg) }
            )
            if !viewModel.pendingAttachments.isEmpty {
                PendingAttachmentsBar(
                    attachments: viewModel.pendingAttachments,
                    onRemove: { viewModel.removeAttachment($0) }
                )
            }
            ChatInputBar(
                viewModel: viewModel,
                inputFocused: $inputFocused,
                webSearchEnabled: $webSearchEnabled,
                theme: theme,
                onShowPhotoPicker: { showPhotoPicker = true },
                onShowFilePicker: { showFilePicker = true },
                onShowImageGen: { showImageGen = true },
                onShowFolderPicker: { showFolderPicker = true },
                onShowToolsAccess: { showToolsAccess = true },
                onSend: { Task { await viewModel.send() } },
                onCancel: { viewModel.cancel() }
            )
        }
        .background(theme.background.ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture { inputFocused = false }
    }

    // MARK: - Left edge swipe (otwiera historię)

    private var edgeSwipeGesture: some Gesture {
        DragGesture(minimumDistance: edgeSwipeMinDistance)
            .onEnded { value in
                guard value.startLocation.x <= edgeSwipeActivationX else { return }
                guard value.translation.width > edgeSwipeMinTranslation else { return }
                guard abs(value.translation.height) < 100 else { return }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showHistory = true
            }
    }

    // MARK: - Helpers

    private func addPhotoAttachment(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        let attachment = Attachment(
            type: .image,
            mimeType: "image/jpeg",
            fileName: "photo_\(Int(Date().timeIntervalSince1970)).jpg",
            base64Data: data.base64EncodedString(),
            textContent: nil
        )
        viewModel.addAttachment(attachment)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

#Preview {
    let store = ConversationStore()
    let modelStore = ModelStore()
    return ChatView(viewModel: ChatViewModel(store: store, modelStore: modelStore))
        .environmentObject(store)
        .environmentObject(modelStore)
}

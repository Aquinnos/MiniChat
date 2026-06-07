//
//  ChatView.swift
//  MiniChat
//
//  Główny ekran czatu z sliding side panel (historia), attachments, animowany streaming.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// PreferenceKey do śledzenia pozycji scrolla (dla sticky-bottom)
struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

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
    @State private var webSearchEnabled: Bool = UserDefaults.standard.object(forKey: "webSearchEnabled") as? Bool ?? true
    @FocusState private var inputFocused: Bool

    // Sliding panel state
    @State private var editingMessage: Message?
    @State private var showImageGen: Bool = false

    private let panelWidth: CGFloat = 300
    private let edgeSwipeThreshold: CGFloat = 60
    private let swipeActivationZone: CGFloat = 40

    private var theme: AppColors { themeManager.colors(for: colorScheme) }

    var body: some View {
        ZStack {
            mainContent

            // Invisible swipe target na lewej krawędzi (30px) - gest otwiera historię
            HStack(spacing: 0) {
                Color.clear
                    .frame(width: 30)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 20)
                            .onEnded { value in
                                // Swipe w prawo z lewej krawędzi
                                if value.translation.width > 70 && abs(value.translation.height) < 100 {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    showHistory = true
                                }
                            }
                    )
                Spacer()
            }
            .allowsHitTesting(true)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showHistory) {
            HistoryView(onSelect: {
                viewModel.refresh()
            })
        }
        .sheet(isPresented: $showModelPicker) {
            ModelPickerView(selectedModel: $modelStore.selectedModel)
        }
        .sheet(isPresented: $showPresets) {
            PresetsView()
        }
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
                // Konwertuj UIImage na Attachment
                if let data = image.jpegData(compressionQuality: 0.85) {
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
            header
            Divider().background(theme.gold.opacity(0.3))
            messagesList
            if !viewModel.pendingAttachments.isEmpty {
                pendingAttachmentsBar
            }
            inputBar
        }
        .background(theme.background.ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture { inputFocused = false }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            // Przycisk historii - DZIAŁA + swipe
            Button {
                showHistory = true
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.title3)
                    .foregroundColor(Theme.blue)
            }
            .frame(width: 36, height: 36)

            Button {
                showModelPicker = true
            } label: {
                HStack(spacing: 6) {
                    VStack(spacing: 0) {
                        Text("MiniChat")
                            .font(.headline)
                            .foregroundColor(Theme.textPrimary)
                        HStack(spacing: 4) {
                            Image(systemName: "cpu")
                                .font(.caption2)
                            Text(viewModel.selectedModel.displayName)
                                .font(.caption2)
                            if viewModel.selectedModel.supportsAttachments {
                                Image(systemName: "paperclip")
                                    .font(.caption2)
                            }
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .foregroundColor(Theme.blue)
                    }
                }
            }
            .buttonStyle(.plain)

            // Przycisk presetu - pokazuje emoji aktywnego preseta lub 🎭
            Button {
                showPresets = true
            } label: {
                Text(presetStore.selectedPreset?.emoji ?? "🎭")
                    .font(.title3)
                    .frame(width: 36, height: 36)
            }

            Spacer()

            Button {
                viewModel.startNewChat()
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.title3)
                    .foregroundColor(Theme.blue)
            }
            .frame(width: 36, height: 36)

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .foregroundColor(Theme.blue)
            }
            .frame(width: 36, height: 36)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.surface)
    }

    // MARK: - Messages

    private var messagesList: some View {
        ScrollViewReader { proxy in
            GeometryReader { outerGeo in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if viewModel.messages.isEmpty {
                            welcomeView
                                .padding(.top, 60)
                        } else {
                            ForEach(viewModel.messages) { message in
                                bubbleForMessage(message)
                                    .id(message.id)
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.92).combined(with: .opacity).combined(with: .move(edge: .bottom)),
                                        removal: .opacity
                                    ))
                            }
                        }
                        // Kotwica do śledzenia pozycji scrolla
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .preference(
                                            key: ScrollOffsetKey.self,
                                            value: geo.frame(in: .global).minY
                                        )
                                }
                            )
                    }
                    .padding(.vertical, 16)
                    .animation(.easeInOut(duration: 0.25), value: viewModel.messages.count)
                }
                .scrollDismissesKeyboard(.interactively)
                .onPreferenceChange(ScrollOffsetKey.self) { offset in
                    // Zapamiętaj pozycję scrolla - sticky bottom działa gdy offset jest blisko dołu
                    let viewportHeight = outerGeo.size.height
                    let distanceFromBottom = abs(offset - viewportHeight + 100)
                    stickyBottom = distanceFromBottom < 50
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    scrollToBottom(proxy: proxy, animated: true)
                }
                .onChange(of: viewModel.messages.last?.content) { _, _ in
                    // Tylko scrolluj jeśli user jest blisko dołu (sticky bottom)
                    // Użyj płynnej spring animacji zamiast skokowej
                    if stickyBottom {
                        withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.85)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
                .onChange(of: viewModel.messages.last?.reasoningContent) { _, _ in
                    if stickyBottom {
                        withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.85)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    scrollToBottom(proxy: proxy, animated: false)
                }
            }
        }
    }

    @State private var stickyBottom: Bool = true

    @ViewBuilder
    private func bubbleForMessage(_ message: Message) -> some View {
        let isLastMessage = viewModel.messages.last?.id == message.id
        let isStreamingThis = viewModel.isStreaming && message.role == .assistant && isLastMessage

        MessageBubbleView(
            message: message,
            isStreaming: isStreamingThis,
            isThinking: viewModel.isThinking,
            isPreparing: viewModel.isPreparingResponse && isStreamingThis,
            onEdit: { msg in
                editingMessage = msg
            },
            onDelete: { msg in
                viewModel.deleteMessage(msg)
            },
            onRegenerate: { msg in
                Task { await viewModel.regenerateFromAssistant(msg) }
            }
        )
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        if animated {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        } else {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }

    private var welcomeView: some View {
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

    // MARK: - Pending attachments

    private var pendingAttachmentsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.pendingAttachments) { attachment in
                    HStack(spacing: 6) {
                        if attachment.isImage, let base64 = attachment.base64Data,
                           let data = Data(base64Encoded: base64),
                           let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 28, height: 28)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        } else {
                            Image(systemName: "doc.fill")
                                .foregroundColor(Theme.blue)
                        }
                        Text(attachment.fileName)
                            .font(.caption)
                            .foregroundColor(Theme.textPrimary)
                            .lineLimit(1)
                        Button {
                            viewModel.removeAttachment(attachment)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Theme.goldSoft.opacity(0.5))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Theme.surface.opacity(0.5))
    }

    // MARK: - Input

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Jeden przycisk "+" z opcjami w menu
            // Photo + file: tylko dla modeli z supportsAttachments (M3)
            // Image gen: działa dla wszystkich (client-side tool)
            // Web search, folder, tools: dla wszystkich
            Menu {
                if viewModel.selectedModel.supportsAttachments {
                    Button {
                        showPhotoPicker = true
                    } label: {
                        Label("Dodaj zdjęcie", systemImage: "photo")
                    }

                    Button {
                        showFilePicker = true
                    } label: {
                        Label("Dodaj plik", systemImage: "paperclip")
                    }
                }

                Button {
                    showImageGen = true
                } label: {
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

                Button {
                    showFolderPicker = true
                } label: {
                    Label("Dodaj do folderu", systemImage: "folder.badge.plus")
                }

                Button {
                    showToolsAccess = true
                } label: {
                    Label("Tools access", systemImage: "wrench.and.screwdriver")
                }
            } label: {
                    if viewModel.isGeneratingImage {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 36, height: 36)
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(theme.blue)
                            .frame(width: 36, height: 36)
                    }
                }
                .disabled(viewModel.isStreaming || viewModel.isGeneratingImage)

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
                    Task { await viewModel.send() }
                }

            Button {
                if viewModel.isStreaming {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    viewModel.cancel()
                } else {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    Task { await viewModel.send() }
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
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.background)
    }

    private var canSend: Bool {
        let hasText = !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasAttachments = !viewModel.pendingAttachments.isEmpty
        return hasText || hasAttachments
    }
}

#Preview {
    let store = ConversationStore()
    let modelStore = ModelStore()
    return ChatView(viewModel: ChatViewModel(store: store, modelStore: modelStore))
        .environmentObject(store)
        .environmentObject(modelStore)
}

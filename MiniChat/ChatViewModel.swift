//
//  ChatViewModel.swift
//  MiniChat
//
//  Główna logika czatu: wysyłanie wiadomości, streaming, załączniki.
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var pendingAttachments: [Attachment] = []
    @Published private(set) var isStreaming: Bool = false
    @Published private(set) var isThinking: Bool = false
    /// True od momentu wysłania do pierwszego chunku (content/reasoning).
    /// Używane do pokazania kropek "myślenia" nawet jeśli model odpowie bardzo szybko.
    @Published private(set) var isPreparingResponse: Bool = false
    @Published var errorMessage: String?

    private let apiClient: MiniMaxAPIClient
    private let store: ConversationStore
    private let modelStore: ModelStore
    private let presetStore: PresetStore
    private var streamTask: Task<Void, Never>?
    private var storeObserver: AnyCancellable?
    private var lastChunkTime: Date = .distantPast
    /// Minimalny interwał między updateami UI podczas streamingu (żeby było widać "pisanie")
    private let streamThrottleInterval: TimeInterval = 0.016  // 16ms = 60 FPS, płynne pisanie

    init(
        store: ConversationStore,
        modelStore: ModelStore,
        presetStore: PresetStore = .shared,
        apiClient: MiniMaxAPIClient = MiniMaxAPIClient()
    ) {
        self.store = store
        self.modelStore = modelStore
        self.presetStore = presetStore
        self.apiClient = apiClient
        observeStore()
    }

    private func observeStore() {
        // Reaguj na zmianę aktywnej rozmowy (np. po usunięciu z historii)
        storeObserver = store.$currentConversationId
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
    }

    var currentConversation: Conversation? {
        store.currentConversation
    }

    var messages: [Message] {
        store.currentConversation?.messages ?? []
    }

    var selectedModel: MiniMaxModel {
        modelStore.selectedModel
    }

    // MARK: - Attachments

    /// Dodaje załącznik do kolejki (max 5)
    func addAttachment(_ attachment: Attachment) {
        guard pendingAttachments.count < 5 else {
            errorMessage = "Max 5 załączników na wiadomość"
            return
        }
        if !pendingAttachments.contains(where: { $0.id == attachment.id }) {
            pendingAttachments.append(attachment)
        }
    }

    /// Usuwa załącznik z kolejki
    func removeAttachment(_ attachment: Attachment) {
        pendingAttachments.removeAll(where: { $0.id == attachment.id })
    }

    /// Czyści wszystkie załączniki
    func clearAttachments() {
        pendingAttachments.removeAll()
    }

    // MARK: - Sending

    /// Wysyła wiadomość użytkownika wraz z załącznikami.
    func send() async {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasAttachments = !pendingAttachments.isEmpty
        guard (!trimmed.isEmpty || hasAttachments), !isStreaming else { return }

        // Sprawdź czy model obsługuje attachments
        if hasAttachments && !selectedModel.supportsAttachments {
            errorMessage = "Model \(selectedModel.displayName) nie obsługuje obrazów i plików. Przełącz się na M3."
            return
        }

        if store.currentConversation == nil {
            store.createNewConversation()
        }

        guard var conversation = store.currentConversation else { return }

        let attachments = pendingAttachments
        let userMessage = Message(
            role: .user,
            content: trimmed,
            attachments: attachments
        )
        conversation.messages.append(userMessage)
        conversation.generateTitleIfNeeded()
        conversation.updatedAt = Date()
        store.currentConversation = conversation

        inputText = ""
        pendingAttachments.removeAll()

        await streamResponse()
    }

    func cancel() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        isThinking = false
        isPreparingResponse = false
    }

    private func streamResponse() async {
        guard let apiKey = KeychainHelper.read(), !apiKey.isEmpty else {
            errorMessage = "Brak API key. Ustaw go w ustawieniach."
            return
        }

        guard var conversation = store.currentConversation else { return }

        let placeholder = Message(role: .assistant, content: "", reasoningContent: "")
        conversation.messages.append(placeholder)
        store.currentConversation = conversation

        isStreaming = true
        isPreparingResponse = true
        isThinking = selectedModel.isReasoning
        errorMessage = nil

        // Wstrzykuj pamięć długoterminową + listę poprzednich rozmów jako system message
        let previousConversations = store.conversations
            .filter { $0.id != conversation.id && !$0.messages.isEmpty }
            .sorted { $0.updatedAt > $1.updatedAt }
        let memoryContext = MemoryStore.shared.asSystemMessage(previousConversations: previousConversations)

        // Model: z preseta jeśli wybrany, inaczej domyślny
        let model = presetStore.selectedPreset?.model ?? selectedModel
        // Tools: z preseta (override) jeśli ma, inaczej domyślna logika
        let toolsOverride = presetStore.apiTools()

        var allMessages: [Message] = []
        // 1) Preset system prompt (najwyższy priorytet)
        if let preset = presetStore.selectedPreset, !preset.systemPrompt.isEmpty {
            allMessages.append(Message(role: .system, content: preset.systemPrompt))
        }
        // 2) Pamięć długoterminowa + poprzednie rozmowy
        if !memoryContext.isEmpty {
            allMessages.append(Message(role: .system, content: memoryContext))
        }
        // 3) Instrukcja o narzędziach (force użycia tool_calls zamiast odpowiedzi z głowy)
        allMessages.append(Message(role: .system, content: """
        ZASADY UŻYCIA NARZĘDZI:
        - Pytania o AKTUALNE informacje (kursy walut, ceny, pogoda, wiadomości, daty) → ZAWSZE wywołaj odpowiedni tool (web_search, get_current_time)
        - Pytania o TREŚĆ załączonych plików (PDF, DOCX, txt, kod) → wywołaj read_file
        - Prośby o OBRAZY → wywołaj generate_image
        - NIGDY nie odpowiadaj z pamięci na pytania o aktualne dane - zawsze użyj tool, nawet jeśli "wiesz" odpowiedź
        """))
        // 4) Właściwa konwersacja
        allMessages.append(contentsOf: conversation.messages.filter { $0.role != .system })

        streamTask = Task {
            do {
                // Jeśli preset ma własne tools - używamy ich (override)
                // W przeciwnym razie - WSZYSTKIE modele dostają 4 domyślne tools
                // (web_search, generate_image, get_current_time, read_file)
                // - M3: ma natywny web search
                // - Inne: client-side tool loop (my wykonujemy search/image gen)
                let webSearchEnabled = UserDefaults.standard.object(forKey: "webSearchEnabled") as? Bool ?? true
                let enableTools: Bool
                if toolsOverride != nil {
                    enableTools = false  // używamy override zamiast domyślnych
                } else {
                    // Domyślnie ON dla wszystkich modeli
                    enableTools = true
                    _ = webSearchEnabled  // zachowane dla potencjalnego toggle
                }

                let stream = apiClient.streamChatCompletion(
                    messages: allMessages,
                    apiKey: apiKey,
                    model: model,
                    enableTools: enableTools,
                    toolsOverride: toolsOverride
                )

                for try await chunk in stream {
                    if Task.isCancelled { break }
                    await appendChunk(chunk)
                }

                await MainActor.run {
                    self.isStreaming = false
                    self.isThinking = false
                    self.isPreparingResponse = false
                    if var conv = self.store.currentConversation {
                        conv.updatedAt = Date()
                        self.store.currentConversation = conv
                    }
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.isStreaming = false
                    self.isThinking = false
                    self.isPreparingResponse = false
                }
            } catch {
                await MainActor.run {
                    self.isStreaming = false
                    self.isThinking = false
                    self.isPreparingResponse = false
                    if let apiErr = error as? APIError {
                        self.errorMessage = apiErr.errorDescription
                    } else {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }

        await streamTask?.value
    }

    private func appendChunk(_ chunk: StreamChunk) async {
        guard var conversation = store.currentConversation else { return }
        guard let lastIndex = conversation.messages.indices.last,
              conversation.messages[lastIndex].role == .assistant else {
            return
        }

        // Throttle: jeśli ostatni update był niedawno, kumuluj w buforze
        let now = Date()
        if now.timeIntervalSince(lastChunkTime) < streamThrottleInterval {
            let delay = streamThrottleInterval - now.timeIntervalSince(lastChunkTime)
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        lastChunkTime = Date()

        if !chunk.content.isEmpty {
            conversation.messages[lastIndex].content += chunk.content
            isPreparingResponse = false
        }
        if !chunk.reasoningContent.isEmpty {
            let existing = conversation.messages[lastIndex].reasoningContent ?? ""
            conversation.messages[lastIndex].reasoningContent = existing + chunk.reasoningContent
            isPreparingResponse = false
        }
        // Wygenerowane obrazy (image generation tool)
        if !chunk.generatedImages.isEmpty {
            if conversation.messages[lastIndex].images == nil {
                conversation.messages[lastIndex].images = []
            }
            conversation.messages[lastIndex].images?.append(contentsOf: chunk.generatedImages)
        }
        store.currentConversation = conversation
    }

    // MARK: - Actions

    func startNewChat() {
        cancel()
        store.createNewConversation()
        pendingAttachments.removeAll()
        errorMessage = nil
        objectWillChange.send()
    }

    /// Wymusza odświeżenie widoku
    func refresh() {
        objectWillChange.send()
    }

    func clearError() {
        errorMessage = nil
    }

    // MARK: - Manual Image Generation

    @Published private(set) var isGeneratingImage: Bool = false

    /// Ręczne generowanie obrazu (z ImageGenSheet) - bez modelu
    func generateImageManually(prompt: String, aspectRatio: String) async {
        guard let apiKey = KeychainHelper.read(), !apiKey.isEmpty else {
            errorMessage = "Brak API key. Ustaw go w ustawieniach."
            return
        }

        // Upewnij się że mamy aktywną konwersację
        if store.currentConversation == nil {
            store.createNewConversation()
        }

        // Dodaj prompt usera jako wiadomość
        guard var conversation = store.currentConversation else { return }
        conversation.messages.append(Message(role: .user, content: "🎨 \(prompt)"))
        conversation.updatedAt = Date()

        // Dodaj placeholder asystenta z markerem "generuję"
        let assistantMsg = Message(
            role: .assistant,
            content: "Generuję obraz...",
            reasoningContent: nil,
            attachments: [],
            images: []
        )
        conversation.messages.append(assistantMsg)
        store.currentConversation = conversation
        isGeneratingImage = true
        errorMessage = nil

        do {
            let result = try await ImageGenerator.shared.generate(
                prompt: prompt,
                apiKey: apiKey,
                aspectRatio: aspectRatio,
                useBase64: true
            )

            // Zaktualizuj ostatnią wiadomość asystenta z obrazem
            if var conv = store.currentConversation,
               let lastIdx = conv.messages.indices.last,
               conv.messages[lastIdx].role == .assistant {
                var newImages: [GeneratedImage] = []
                if let b64 = result.base64Data {
                    newImages.append(GeneratedImage(
                        base64Data: b64,
                        mimeType: result.mimeType,
                        prompt: prompt
                    ))
                }
                conv.messages[lastIdx] = Message(
                    id: conv.messages[lastIdx].id,
                    role: .assistant,
                    content: "Wygenerowałem obraz: \"\(prompt)\"",
                    reasoningContent: nil,
                    attachments: [],
                    images: newImages,
                    timestamp: conv.messages[lastIdx].timestamp
                )
                conv.updatedAt = Date()
                store.currentConversation = conv
            }
        } catch {
            // Wyczyść placeholder, pokaż błąd
            if var conv = store.currentConversation,
               let lastIdx = conv.messages.indices.last,
               conv.messages[lastIdx].role == .assistant {
                conv.messages[lastIdx] = Message(
                    id: conv.messages[lastIdx].id,
                    role: .assistant,
                    content: "❌ Nie udało się wygenerować obrazu: \(error.localizedDescription)",
                    reasoningContent: nil,
                    attachments: [],
                    images: [],
                    timestamp: conv.messages[lastIdx].timestamp
                )
                store.currentConversation = conv
            }
            if let imgErr = error as? ImageGeneratorError {
                errorMessage = imgErr.errorDescription
            } else {
                errorMessage = error.localizedDescription
            }
        }

        isGeneratingImage = false
    }

    // MARK: - Edit & Regenerate

    /// Edytuje wiadomość użytkownika: zastępuje ją nową treścią, usuwa wszystko po niej,
    /// i wysyła ponownie request do modelu.
    func editAndRegenerate(messageId: UUID, newContent: String, newAttachments: [Attachment]) async {
        guard var conversation = store.currentConversation else { return }
        guard let idx = conversation.messages.firstIndex(where: { $0.id == messageId }) else { return }
        guard conversation.messages[idx].role == .user else { return }

        // Sprawdź attachments
        if !newAttachments.isEmpty && !selectedModel.supportsAttachments {
            errorMessage = "Model \(selectedModel.displayName) nie obsługuje załączników. Przełącz się na M3."
            return
        }

        cancel() // anuluj ewentualny streaming

        // Zamień wiadomość + usuń wszystko po niej
        conversation.messages[idx] = Message(
            id: messageId,
            role: .user,
            content: newContent,
            attachments: newAttachments
        )
        // Usuń wiadomości po edytowanej
        if idx + 1 < conversation.messages.count {
            conversation.messages.removeSubrange((idx + 1)...)
        }
        conversation.updatedAt = Date()
        conversation.generateTitleIfNeeded()
        store.currentConversation = conversation
        objectWillChange.send()

        await streamResponse()
    }

    /// Regeneruje odpowiedź asystenta: znajduje user message przed asystentem,
    /// usuwa odpowiedź i wysyła nowy request.
    func regenerateFromAssistant(_ assistantMessage: Message) async {
        guard var conversation = store.currentConversation else { return }
        guard let asstIdx = conversation.messages.firstIndex(where: { $0.id == assistantMessage.id }) else { return }

        cancel()

        // Znajdź poprzednią wiadomość user
        let userMessage: Message?
        if asstIdx > 0, conversation.messages[asstIdx - 1].role == .user {
            userMessage = conversation.messages[asstIdx - 1]
        } else {
            userMessage = nil
        }

        // Usuń wiadomość asystenta
        conversation.messages.remove(at: asstIdx)
        store.currentConversation = conversation
        objectWillChange.send()

        // Jeśli był user message przed, wyślij ponownie
        if userMessage != nil {
            await streamResponse()
        }
    }

    /// Usuwa wiadomość (i wszystko po niej)
    func deleteMessage(_ message: Message) {
        guard var conversation = store.currentConversation else { return }
        guard let idx = conversation.messages.firstIndex(where: { $0.id == message.id }) else { return }
        // Nie usuwaj wiadomości user na końcu (jeśli to ostatnia)
        if idx == conversation.messages.count - 1 && message.role == .user {
            conversation.messages.remove(at: idx)
        } else {
            // Usuń tę + wszystko po
            conversation.messages.removeSubrange(idx...)
        }
        store.currentConversation = conversation
        objectWillChange.send()
    }
}

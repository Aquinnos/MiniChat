//
//  Models.swift
//  MiniChat
//
//  Modele danych: Message, Conversation, Attachment.
//

import Foundation

// MARK: - Attachment

struct Attachment: Identifiable, Codable, Hashable {
    let id: UUID
    let type: AttachmentType
    let mimeType: String
    let fileName: String
    /// Base64 encoded data (dla image) lub raw bytes (dla plików tekstowych)
    let base64Data: String?
    /// Tekstowa zawartość pliku (dla text/csv/json itp.)
    let textContent: String?

    init(
        id: UUID = UUID(),
        type: AttachmentType,
        mimeType: String,
        fileName: String,
        base64Data: String? = nil,
        textContent: String? = nil
    ) {
        self.id = id
        self.type = type
        self.mimeType = mimeType
        self.fileName = fileName
        self.base64Data = base64Data
        self.textContent = textContent
    }

    enum AttachmentType: String, Codable {
        case image
        case file
    }

    /// Rozmiar w KB (przybliżony)
    var sizeKB: Double {
        if let data = base64Data {
            // base64 jest ~33% większe niż oryginalne dane
            return Double(data.count) * 0.75 / 1024
        }
        if let text = textContent {
            return Double(text.utf8.count) / 1024
        }
        return 0
    }

    /// Czy to obrazek
    var isImage: Bool { type == .image }
}

// MARK: - Message

struct Message: Identifiable, Codable, Hashable {
    let id: UUID
    let role: Role
    var content: String
    var reasoningContent: String?
    var attachments: [Attachment]
    var images: [GeneratedImage]?
    let timestamp: Date

    // Hash z dokładnością do sekundy (timestamp.nanosecond różni się między wiadomościami
    // nawet jeśli user ich nie rozróżnia). Bez tego dwa wiadomości utworzone w odstępie 1ns
    // miałyby różne hashe, co jest szumem.
    static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.id == rhs.id
            && lhs.role == rhs.role
            && lhs.content == rhs.content
            && lhs.reasoningContent == rhs.reasoningContent
            && lhs.attachments == rhs.attachments
            && lhs.images == rhs.images
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(role)
        hasher.combine(content)
        hasher.combine(reasoningContent)
        hasher.combine(attachments)
        hasher.combine(images)
    }

    init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        reasoningContent: String? = nil,
        attachments: [Attachment] = [],
        images: [GeneratedImage]? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.reasoningContent = reasoningContent
        self.attachments = attachments
        self.images = images
        self.timestamp = timestamp
    }

    // Custom decoder - akceptuj brakujące pole `images` w starych danych
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.role = try container.decode(Role.self, forKey: .role)
        self.content = try container.decode(String.self, forKey: .content)
        self.reasoningContent = try container.decodeIfPresent(String.self, forKey: .reasoningContent)
        self.attachments = try container.decodeIfPresent([Attachment].self, forKey: .attachments) ?? []
        self.images = try container.decodeIfPresent([GeneratedImage].self, forKey: .images)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
    }

    private enum CodingKeys: String, CodingKey {
        case id, role, content, reasoningContent, attachments, images, timestamp
    }

    enum Role: String, Codable {
        case user
        case assistant
        case system

        var isUser: Bool { self == .user }
    }

    /// Czy ma załączniki
    var hasAttachments: Bool { !attachments.isEmpty }

    /// Czy ma wygenerowane obrazy
    var hasImages: Bool { (images?.isEmpty == false) }
}

// MARK: - Conversation

struct Conversation: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var messages: [Message]
    let createdAt: Date
    var updatedAt: Date
    var isPinned: Bool
    var tags: [String]
    var folderId: UUID?

    init(
        id: UUID = UUID(),
        title: String = "Nowa rozmowa",
        messages: [Message] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isPinned: Bool = false,
        tags: [String] = [],
        folderId: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPinned = isPinned
        self.tags = tags
        self.folderId = folderId
    }

    // MARK: - Backward-compatible decoder (stare pliki bez isPinned/tags/folderId)
    enum CodingKeys: String, CodingKey {
        case id, title, messages, createdAt, updatedAt, isPinned, tags, folderId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.title = try c.decode(String.self, forKey: .title)
        self.messages = try c.decode([Message].self, forKey: .messages)
        self.createdAt = try c.decode(Date.self, forKey: .createdAt)
        self.updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        self.isPinned = (try? c.decode(Bool.self, forKey: .isPinned)) ?? false
        self.tags = (try? c.decode([String].self, forKey: .tags)) ?? []
        self.folderId = try? c.decode(UUID.self, forKey: .folderId)
    }

    /// Maksymalna długość automatycznie generowanego tytułu
    static let maxAutoTitleLength = 40

    mutating func generateTitleIfNeeded() {
        guard title == "Nowa rozmowa",
              let firstUserMessage = messages.first(where: { $0.role == .user }) else {
            return
        }
        let trimmed = firstUserMessage.content
            .trimmingCharacters(in: .whitespacesAndNewlines)
        title = String(trimmed.prefix(Self.maxAutoTitleLength))
        if trimmed.count > Self.maxAutoTitleLength { title += "…" }
    }
}

// MARK: - ConversationStats

/// Statystyki wyliczane lokalnie z kolekcji konwersacji (do widoku Insights).
struct ConversationStats: Equatable {
    let totalConversations: Int
    let totalMessages: Int
    let totalTags: Int
    let topTags: [TagCount]
    let longestConversation: ConversationLength?
    let dailyActivity: [DailyActivity]
    let totalCharacters: Int

    struct TagCount: Equatable, Identifiable {
        var id: String { tag }
        let tag: String
        let count: Int
    }

    struct ConversationLength: Equatable, Identifiable {
        var id: UUID { conversationId }
        let conversationId: UUID
        let title: String
        let messageCount: Int
    }

    struct DailyActivity: Equatable, Identifiable {
        var id: Date { date }
        let date: Date
        let count: Int
    }

    static let empty = ConversationStats(
        totalConversations: 0,
        totalMessages: 0,
        totalTags: 0,
        topTags: [],
        longestConversation: nil,
        dailyActivity: [],
        totalCharacters: 0
    )

    /// Szacunkowa liczba tokenów (chars/4 - przybliżenie dla LLM).
    var estimatedTokens: Int { totalCharacters / 4 }
}

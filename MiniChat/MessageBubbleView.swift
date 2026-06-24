//
//  MessageBubbleView.swift
//  MiniChat
//
//  Bubble z ogonkiem jak w iMessage, animowany streaming, czyszczenie polskich znaków.
//

import SwiftUI
import UIKit

struct MessageBubbleView: View {
    let message: Message
    let isStreaming: Bool
    let isThinking: Bool
    let isPreparing: Bool
    let onEdit: ((Message) -> Void)?
    let onDelete: ((Message) -> Void)?
    let onRegenerate: ((Message) -> Void)?
    let onFork: ((Message) -> Void)?

    @State private var showReasoning: Bool = false

    init(
        message: Message,
        isStreaming: Bool,
        isThinking: Bool,
        isPreparing: Bool = false,
        onEdit: ((Message) -> Void)? = nil,
        onDelete: ((Message) -> Void)? = nil,
        onRegenerate: ((Message) -> Void)? = nil,
        onFork: ((Message) -> Void)? = nil
    ) {
        self.message = message
        self.isStreaming = isStreaming
        self.isThinking = isThinking
        self.isPreparing = isPreparing
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onRegenerate = onRegenerate
        self.onFork = onFork
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            if message.role.isUser {
                Spacer(minLength: 50)
                bubbleContent
            } else {
                bubbleContent
                Spacer(minLength: 50)
            }
        }
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private var bubbleContent: some View {
        VStack(alignment: message.role.isUser ? .trailing : .leading, spacing: 6) {
            // Reasoning panel (rozważania)
            if let reasoning = message.reasoningContent, !reasoning.isEmpty {
                reasoningPanel(reasoning)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)),
                        removal: .opacity
                    ))
            }

            // Główna treść
            mainBubble
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                    removal: .opacity
                ))
        }
        .contextMenu {
            contextMenuContent
        }
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        // Kopiuj - działa dla każdej wiadomości
        Button {
            UIPasteboard.general.string = message.content
        } label: {
            Label("Kopiuj tekst", systemImage: "doc.on.doc")
        }

        // Kopiuj z reasoning (dla asystenta)
        if !message.role.isUser, let reasoning = message.reasoningContent, !reasoning.isEmpty {
            Button {
                UIPasteboard.general.string = reasoning
            } label: {
                Label("Kopiuj rozważania", systemImage: "brain")
            }
        }

        Divider()

        // Edytuj - tylko dla user
        if message.role.isUser, let onEdit = onEdit, !isStreaming {
            Button {
                onEdit(message)
            } label: {
                Label("Edytuj", systemImage: "pencil")
            }
        }

        // Regeneruj - tylko dla asystenta
        if !message.role.isUser, let onRegenerate = onRegenerate, !isStreaming {
            Button {
                onRegenerate(message)
            } label: {
                Label("Regeneruj odpowiedź", systemImage: "arrow.clockwise")
            }
        }

        // Fork - dla każdej (tworzy nową rozmowę skopiowaną do tej wiadomości)
        if let onFork = onFork, !isStreaming {
            Button {
                onFork(message)
            } label: {
                Label("Utwórz fork od tego momentu", systemImage: "arrow.triangle.branch")
            }
        }

        // Usuń - dla każdej
        if let onDelete = onDelete, !isStreaming {
            Divider()
            Button(role: .destructive) {
                onDelete(message)
            } label: {
                Label("Usuń", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private var mainBubble: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if message.role.isUser {
                userContent
            } else {
                assistantContent
            }
        }
    }

    // MARK: - User bubble (niebieski, z ogonkiem po prawej)

    private var userContent: some View {
        VStack(alignment: .trailing, spacing: 8) {
            // Załączniki
            if message.hasAttachments {
                attachmentsView
            }

            if !message.content.isEmpty {
                markdownWithCode(cleanText(message.content), color: .white, isUser: true)
                    .font(.body)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(message.timestamp, style: .time)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.userBubble)
        .clipShape(BubbleShape(isUser: true))
        .shadow(color: Theme.blue.opacity(0.15), radius: 4, x: 0, y: 2)
    }

    // MARK: - Attachments grid

    private var attachmentsView: some View {
        let columns = [
            GridItem(.adaptive(minimum: 80, maximum: 120), spacing: 4)
        ]

        return LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
            ForEach(message.attachments) { attachment in
                attachmentThumbnail(attachment)
            }
        }
    }

    @ViewBuilder
    private func attachmentThumbnail(_ att: Attachment) -> some View {
        if att.isImage, let base64 = att.base64Data,
           let data = Data(base64Encoded: base64),
           let uiImage = UIImage(data: data) {
            // Obrazek
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 90, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            // Plik
            VStack(spacing: 4) {
                Image(systemName: fileIcon(for: att.mimeType))
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                Text(att.fileName)
                    .font(.system(size: 9))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(width: 90, height: 90)
            .background(Color.white.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
        }
    }

    private func fileIcon(for mimeType: String) -> String {
        if mimeType.hasPrefix("text/") { return "doc.text" }
        if mimeType.contains("pdf") { return "doc.richtext" }
        if mimeType.contains("json") { return "curlybraces" }
        if mimeType.contains("csv") { return "tablecells" }
        if mimeType.contains("zip") || mimeType.contains("archive") { return "doc.zipper" }
        return "doc.fill"
    }

    // MARK: - Assistant bubble (złoty, z ogonkiem po lewej)

    private var assistantContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 0) {
                if (isPreparing || isStreaming) && message.content.isEmpty && !message.hasImages {
                    // Kropki "myślenia" - widoczne od wysłania do pierwszego chunku content/reasoning
                    ThinkingDots()
                        .padding(.leading, 4)
                } else {
                    markdownWithCode(cleanText(message.content), color: Theme.textPrimary, isUser: false)
                        .font(.body)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)

                    // Migający kursor podczas streamingu (gdy już jest content)
                    if isStreaming && !message.content.isEmpty {
                        BlinkingCursor()
                            .padding(.leading, 2)
                            .padding(.top, 2)
                            .transition(.opacity)
                    }
                }
            }

            // Wygenerowane obrazy
            if let images = message.images, !images.isEmpty {
                generatedImagesView(images: images)
            }

            if message.role == .assistant && !isStreaming && (!message.content.isEmpty || (message.images?.isEmpty == false)) {
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary.opacity(0.6))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.assistantBubble)
        .clipShape(BubbleShape(isUser: false))
        .shadow(color: Theme.gold.opacity(0.15), radius: 4, x: 0, y: 2)
    }

    // MARK: - Generated images

    private func generatedImagesView(images: [GeneratedImage]) -> some View {
        VStack(spacing: 8) {
            ForEach(Array(images.enumerated()), id: \.offset) { _, image in
                if let data = Data(base64Encoded: image.base64Data),
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 280, maxHeight: 400)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.gold.opacity(0.4), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        .contextMenu {
                            Button {
                                if let pngData = uiImage.pngData() {
                                    if let saved = UIImage(data: pngData) {
                                        UIImageWriteToSavedPhotosAlbum(saved, nil, nil, nil)
                                    }
                                }
                            } label: {
                                Label("Zapisz do zdjęć", systemImage: "square.and.arrow.down")
                            }
                            Button {
                                UIPasteboard.general.image = uiImage
                            } label: {
                                Label("Kopiuj obraz", systemImage: "doc.on.doc")
                            }
                        }
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Markdown text

    @ViewBuilder
    private func markdownText(_ text: String, color: Color) -> some View {
        if let attributed = try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(
                allowsExtendedAttributes: false,
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        ) {
            Text(attributed)
                .foregroundColor(color)
        } else {
            Text(text)
                .foregroundColor(color)
        }
    }

    // MARK: - Markdown with code blocks (syntax highlighted)

    /// Segment markdownu: albo tekst, albo code block
    private enum MarkdownSegment {
        case text(String)
        case code(String, language: String?)
    }

    /// Parsuje markdown dzieląc go na segmenty textowe i code blocki.
    /// Obsługuje ```lang\n...\n``` format.
    private func parseMarkdownSegments(_ text: String) -> [MarkdownSegment] {
        var segments: [MarkdownSegment] = []
        var currentText = ""
        var i = text.startIndex

        while i < text.endIndex {
            // Szukaj ```lang\n
            if let codeStart = text.range(of: "```", range: i..<text.endIndex) {
                // Tekst przed blokiem kodu
                if codeStart.lowerBound > i {
                    currentText.append(contentsOf: text[i..<codeStart.lowerBound])
                }
                // Znajdź język (pierwsza linia po ```)
                let afterFence = codeStart.upperBound
                let langEnd = text.range(of: "\n", range: afterFence..<text.endIndex)?.lowerBound ?? text.endIndex
                let lang = String(text[afterFence..<langEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
                let langOrNil = lang.isEmpty ? nil : lang

                // Znajdź zamknięcie ```
                if let codeEnd = text.range(of: "```", range: langEnd..<text.endIndex) {
                    let codeContent = String(text[langEnd..<codeEnd.lowerBound])
                    if !currentText.isEmpty {
                        segments.append(.text(currentText))
                        currentText = ""
                    }
                    segments.append(.code(codeContent, language: langOrNil))
                    i = codeEnd.upperBound
                } else {
                    // Niezamknięty blok - traktuj resztę jako tekst
                    currentText.append(contentsOf: text[codeStart.lowerBound..<text.endIndex])
                    i = text.endIndex
                    break
                }
            } else {
                currentText.append(contentsOf: text[i..<text.endIndex])
                break
            }
        }

        if !currentText.isEmpty {
            segments.append(.text(currentText))
        }
        return segments
    }

    /// Renderuje markdown z code blockami (syntax highlighted) - VStack z segmentami
    @ViewBuilder
    private func markdownWithCode(_ text: String, color: Color, isUser: Bool) -> some View {
        let segments = parseMarkdownSegments(text)
        // Jeśli nie ma code blocków, użyj szybkiej ścieżki
        let hasCodeBlock = segments.contains { if case .code = $0 { return true } else { return false } }
        if !hasCodeBlock {
            markdownText(text, color: color)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    switch segment {
                    case .text(let t):
                        markdownText(t, color: color)
                    case .code(let code, let lang):
                        codeBlockView(code: code, language: lang, isUser: isUser)
                    }
                }
            }
        }
    }

    /// Pojedynczy blok kodu z syntax highlighting + nagłówek z językiem + copy
    @ViewBuilder
    private func codeBlockView(code: String, language: String?, isUser: Bool) -> some View {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let lang = language ?? CodeSyntaxHighlighter.autoDetectLanguageStatic(trimmed)
        let attributed = isUser
            ? CodeSyntaxHighlighter.highlightForUser(trimmed, language: lang)
            : CodeSyntaxHighlighter.highlight(trimmed, language: lang)

        VStack(alignment: .leading, spacing: 0) {
            // Nagłówek z językiem + copy
            HStack {
                Text(lang.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(isUser ? .white.opacity(0.85) : Theme.gold)
                Spacer()
                Button {
                    UIPasteboard.general.string = trimmed
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundColor(isUser ? .white.opacity(0.7) : Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isUser ? Color.white.opacity(0.15) : Theme.gold.opacity(0.15))

            // Kod z syntax highlighting
            ScrollView(.horizontal, showsIndicators: false) {
                Text(attributed)
                    .lineLimit(nil)
                    .fixedSize(horizontal: true, vertical: true)
                    .padding(10)
                    .textSelection(.enabled)
            }
            .background(isUser ? Color.black.opacity(0.2) : Color(white: 0.96))
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isUser ? Color.white.opacity(0.2) : Theme.gold.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Reasoning panel

    @ViewBuilder
    private func reasoningPanel(_ reasoning: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showReasoning.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showReasoning ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                    Image(systemName: "brain.head.profile")
                        .font(.caption)
                    Text("Rozważania")
                        .font(.caption.bold())
                    if isThinking && message.content.isEmpty {
                        Text("• myśli…")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                }
                .foregroundColor(Theme.blue)
            }
            .buttonStyle(.plain)

            if showReasoning {
                Text(cleanText(reasoning))
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Theme.blueSoft.opacity(0.3))
                    )
                    .textSelection(.enabled)
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.blueSoft.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Czyszczenie polskich znaków (NIE usuwamy ZWJ - psuje emoji!)

    private func cleanText(_ text: String) -> String {
        var result = text

        // Normalizacja Unicode - NFC (composed) - naprawia "rozsypane" polskie znaki
        result = result.precomposedStringWithCanonicalMapping

        // Usuwanie TYLKO bezpiecznych białych znaków
        // UWAGA: NIE usuwamy ZWJ (\u{200D}) - to jest potrzebne dla emoji!
        result = result.replacingOccurrences(of: "\u{200B}", with: "")  // zero-width space
        result = result.replacingOccurrences(of: "\u{FEFF}", with: "")  // BOM
        result = result.replacingOccurrences(of: "\u{00A0}", with: " ") // non-breaking space

        // Smart quotes → polskie
        result = result.replacingOccurrences(of: "\u{201C}", with: "„")  // " → „
        result = result.replacingOccurrences(of: "\u{201D}", with: "\"") // " → "

        // Typowe dziwne escape sequences (gdyby model zwrócił literalny tekst)
        result = result.replacingOccurrences(of: "\\n", with: "\n")
        result = result.replacingOccurrences(of: "\\\"", with: "\"")
        result = result.replacingOccurrences(of: "\\t", with: "\t")

        // Wielokrotne nowe linie → max 3
        while result.contains("\n\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n\n", with: "\n\n\n")
        }

        return result
    }
}

// MARK: - Bubble shape (z ogonkiem)

struct BubbleShape: Shape {
    let isUser: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 18
        let tailSize: CGFloat = 8

        var path = Path()

        let w = rect.width
        let h = rect.height

        if isUser {
            // Bubble z ogonkiem po prawej na dole
            path.move(to: CGPoint(x: radius, y: 0))
            path.addLine(to: CGPoint(x: w - radius, y: 0))
            path.addQuadCurve(
                to: CGPoint(x: w, y: radius),
                control: CGPoint(x: w, y: 0)
            )
            path.addLine(to: CGPoint(x: w, y: h - radius - tailSize))

            // Ogonek
            path.addLine(to: CGPoint(x: w + tailSize, y: h - tailSize))
            path.addLine(to: CGPoint(x: w - tailSize, y: h))

            path.addLine(to: CGPoint(x: radius, y: h))
            path.addQuadCurve(
                to: CGPoint(x: 0, y: h - radius),
                control: CGPoint(x: 0, y: h)
            )
            path.addLine(to: CGPoint(x: 0, y: radius))
            path.addQuadCurve(
                to: CGPoint(x: radius, y: 0),
                control: CGPoint(x: 0, y: 0)
            )
        } else {
            // Bubble z ogonkiem po lewej na dole
            path.move(to: CGPoint(x: radius, y: 0))
            path.addLine(to: CGPoint(x: w - radius, y: 0))
            path.addQuadCurve(
                to: CGPoint(x: w, y: radius),
                control: CGPoint(x: w, y: 0)
            )
            path.addLine(to: CGPoint(x: w, y: h - radius))
            path.addQuadCurve(
                to: CGPoint(x: w - radius, y: h),
                control: CGPoint(x: w, y: h)
            )
            path.addLine(to: CGPoint(x: tailSize, y: h))

            // Ogonek
            path.addLine(to: CGPoint(x: -tailSize, y: h - tailSize))
            path.addLine(to: CGPoint(x: tailSize, y: h - radius - tailSize))

            path.addLine(to: CGPoint(x: radius, y: h - radius))
            path.addQuadCurve(
                to: CGPoint(x: 0, y: h - radius - radius),
                control: CGPoint(x: 0, y: h - radius)
            )
            path.addLine(to: CGPoint(x: 0, y: radius))
            path.addQuadCurve(
                to: CGPoint(x: radius, y: 0),
                control: CGPoint(x: 0, y: 0)
            )
        }

        return path
    }
}

// MARK: - 3 animowane kropki ("myślenie")

struct ThinkingDots: View {
    @State private var phase: Int = 0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Theme.gold)
                    .frame(width: 8, height: 8)
                    .opacity(phase == i ? 1.0 : 0.3)
                    .scaleEffect(phase == i ? 1.2 : 0.85)
                    .animation(.easeInOut(duration: 0.4), value: phase)
            }
        }
        .frame(height: 24)
        .onAppear {
            // Pętla animacji - 0 → 1 → 2 → 0
            Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                withAnimation {
                    phase = (phase + 1) % 3
                }
            }
        }
    }
}

// MARK: - Migający kursor (jak w terminalu)

struct BlinkingCursor: View {
    @State private var opacity: Double = 1.0
    let color: Color = Theme.gold

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 2, height: 16)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    opacity = 0.2
                }
            }
    }
}

#Preview {
    VStack(spacing: 12) {
        MessageBubbleView(
            message: Message(role: .user, content: "Hej! Jak się masz? 🇵🇱"),
            isStreaming: false,
            isThinking: false
        )
        MessageBubbleView(
            message: Message(
                role: .assistant,
                content: "Cześć! Mogę pomóc po polsku 😊",
                reasoningContent: "Piszę po polsku."
            ),
            isStreaming: false,
            isThinking: false
        )
        MessageBubbleView(
            message: Message(role: .assistant, content: "", reasoningContent: "Myślę…"),
            isStreaming: true,
            isThinking: true
        )
    }
    .padding()
    .background(Theme.background)
}

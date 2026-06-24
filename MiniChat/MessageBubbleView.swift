//
//  MessageBubbleView.swift
//  MiniChat
//
//  Bubble z ogonkiem jak w iMessage, animowany streaming, kontekstowe menu.
//  Większe sub-komponenty są wydzielone do Views/MessageBubble/.
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
    @State private var cleanedContent: String = ""
    @State private var cleanedReasoning: String = ""

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
        .onAppear { updateCleaned() }
        // Czyść tekst tylko po zakończeniu streamu - podczas streamingu renderuj surowy
        // tekst z message.content (czyszczenie 8 regexami na każdym chunku jest kosztowne).
        .onChange(of: isStreaming) { _, streaming in
            if !streaming { updateCleaned() }
        }
        .onChange(of: message.content) { _, _ in
            if !isStreaming { updateCleaned() }
        }
        .onChange(of: message.reasoningContent) { _, _ in
            if !isStreaming { updateCleaned() }
        }
    }

    private func updateCleaned() {
        cleanedContent = TextCleaning.clean(message.content)
        cleanedReasoning = message.reasoningContent.map(TextCleaning.clean) ?? ""
    }

    @ViewBuilder
    private var bubbleContent: some View {
        VStack(alignment: message.role.isUser ? .trailing : .leading, spacing: 6) {
            if let reasoning = message.reasoningContent, !reasoning.isEmpty {
                ReasoningPanel(
                    reasoning: cleanedReasoning,
                    isThinking: isThinking,
                    contentEmpty: message.content.isEmpty,
                    expanded: $showReasoning
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                    removal: .opacity
                ))
            }

            mainBubble
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                    removal: .opacity
                ))
        }
        .contextMenu { contextMenuContent }
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        Button {
            UIPasteboard.general.string = message.content
        } label: {
            Label("Kopiuj tekst", systemImage: "doc.on.doc")
        }

        if !message.role.isUser, let reasoning = message.reasoningContent, !reasoning.isEmpty {
            Button {
                UIPasteboard.general.string = reasoning
            } label: {
                Label("Kopiuj rozważania", systemImage: "brain")
            }
        }

        Divider()

        if message.role.isUser, let onEdit = onEdit, !isStreaming {
            Button {
                onEdit(message)
            } label: {
                Label("Edytuj", systemImage: "pencil")
            }
        }

        if !message.role.isUser, let onRegenerate = onRegenerate, !isStreaming {
            Button {
                onRegenerate(message)
            } label: {
                Label("Regeneruj odpowiedź", systemImage: "arrow.clockwise")
            }
        }

        if let onFork = onFork, !isStreaming {
            Button {
                onFork(message)
            } label: {
                Label("Utwórz fork od tego momentu", systemImage: "arrow.triangle.branch")
            }
        }

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

    private var userContent: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if message.hasAttachments {
                attachmentsGrid
            }

            if !message.content.isEmpty {
                MarkdownText(text: cleanedContent, color: .white, isUser: true)
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

    private var attachmentsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 80, maximum: 120), spacing: 4)],
            alignment: .leading,
            spacing: 4
        ) {
            ForEach(message.attachments) { attachment in
                AttachmentThumb(attachment: attachment)
            }
        }
    }

    private var assistantContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 0) {
                if (isPreparing || isStreaming) && message.content.isEmpty && !message.hasImages {
                    ThinkingDots()
                        .padding(.leading, 4)
                } else {
                    MarkdownText(text: cleanedContent, color: Theme.textPrimary, isUser: false)
                        .font(.body)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)

                    if isStreaming && !message.content.isEmpty {
                        BlinkingCursor()
                            .padding(.leading, 2)
                            .padding(.top, 2)
                            .transition(.opacity)
                    }
                }
            }

            if let images = message.images, !images.isEmpty {
                generatedImagesStack(images: images)
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

    private func generatedImagesStack(images: [GeneratedImage]) -> some View {
        VStack(spacing: 8) {
            ForEach(images) { image in
                GeneratedImageBubbleView(image: image)
            }
        }
        .padding(.top, 4)
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
            path.addQuadCurve(to: CGPoint(x: w, y: radius), control: CGPoint(x: w, y: 0))
            path.addLine(to: CGPoint(x: w, y: h - radius - tailSize))
            path.addLine(to: CGPoint(x: w + tailSize, y: h - tailSize))
            path.addLine(to: CGPoint(x: w - tailSize, y: h))
            path.addLine(to: CGPoint(x: radius, y: h))
            path.addQuadCurve(to: CGPoint(x: 0, y: h - radius), control: CGPoint(x: 0, y: h))
            path.addLine(to: CGPoint(x: 0, y: radius))
            path.addQuadCurve(to: CGPoint(x: radius, y: 0), control: CGPoint(x: 0, y: 0))
        } else {
            // Bubble z ogonkiem po lewej na dole
            path.move(to: CGPoint(x: radius, y: 0))
            path.addLine(to: CGPoint(x: w - radius, y: 0))
            path.addQuadCurve(to: CGPoint(x: w, y: radius), control: CGPoint(x: w, y: 0))
            path.addLine(to: CGPoint(x: w, y: h - radius))
            path.addQuadCurve(to: CGPoint(x: w - radius, y: h), control: CGPoint(x: w, y: h))
            path.addLine(to: CGPoint(x: tailSize, y: h))
            path.addLine(to: CGPoint(x: -tailSize, y: h - tailSize))
            path.addLine(to: CGPoint(x: tailSize, y: h - radius - tailSize))
            path.addLine(to: CGPoint(x: radius, y: h - radius))
            path.addQuadCurve(to: CGPoint(x: 0, y: h - radius - radius), control: CGPoint(x: 0, y: h - radius))
            path.addLine(to: CGPoint(x: 0, y: radius))
            path.addQuadCurve(to: CGPoint(x: radius, y: 0), control: CGPoint(x: 0, y: 0))
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
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 400_000_000)
                guard !Task.isCancelled else { break }
                withAnimation { phase = (phase + 1) % 3 }
            }
        }
    }
}

// MARK: - Migający kursor (jak w terminalu)

struct BlinkingCursor: View {
    @State private var opacity: Double = 1.0

    var body: some View {
        Rectangle()
            .fill(Theme.gold)
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
            message: Message(role: .user, content: "Hej! Jak się masz?"),
            isStreaming: false,
            isThinking: false
        )
        MessageBubbleView(
            message: Message(
                role: .assistant,
                content: "Cześć! Mogę pomóc po polsku.",
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

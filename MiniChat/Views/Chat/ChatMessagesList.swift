//
//  ChatMessagesList.swift
//  MiniChat
//
//  Scrollowalna lista wiadomości ze sticky-bottom (auto-scroll gdy user blisko dołu).
//

import SwiftUI

struct ChatMessagesList: View {
    @ObservedObject var viewModel: ChatViewModel
    let onEdit: (Message) -> Void
    let onDelete: (Message) -> Void
    let onRegenerate: (Message) -> Void
    let onFork: (Message) -> Void

    @State private var bottomVisibleId: UUID?

    private var isAtBottom: Bool {
        guard let bottomId = bottomVisibleId else { return true }
        guard let lastId = viewModel.messages.last?.id else { return true }
        return bottomId == lastId
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if viewModel.messages.isEmpty {
                        ChatWelcomeView(viewModel: viewModel)
                            .padding(.top, 60)
                    } else {
                        ForEach(viewModel.messages) { message in
                            bubbleForMessage(message)
                                .id(message.id)
                                .transition(.opacity)
                        }
                    }
                }
                .padding(.vertical, 16)
                .scrollTargetLayout()
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollPosition(id: $bottomVisibleId, anchor: .bottom)
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToLast(proxy: proxy)
            }
            .onChange(of: viewModel.messages.last?.content) { _, _ in
                if isAtBottom {
                    scrollToLast(proxy: proxy, animated: true)
                }
            }
            .onChange(of: viewModel.messages.last?.reasoningContent) { _, _ in
                if isAtBottom {
                    scrollToLast(proxy: proxy, animated: true)
                }
            }
            .onAppear {
                scrollToLast(proxy: proxy, animated: false)
            }
        }
    }

    @ViewBuilder
    private func bubbleForMessage(_ message: Message) -> some View {
        let isLastMessage = viewModel.messages.last?.id == message.id
        let isStreamingThis = viewModel.isStreaming && message.role == .assistant && isLastMessage

        MessageBubbleView(
            message: message,
            isStreaming: isStreamingThis,
            isThinking: viewModel.isThinking,
            isPreparing: viewModel.isPreparingResponse && isStreamingThis,
            onEdit: onEdit,
            onDelete: onDelete,
            onRegenerate: onRegenerate,
            onFork: onFork
        )
    }

    private func scrollToLast(proxy: ScrollViewProxy, animated: Bool = true) {
        guard let last = viewModel.messages.last else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }
}

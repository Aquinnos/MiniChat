//
//  MiniChatApp.swift
//  MiniChat
//

import SwiftUI

@main
struct MiniChatApp: App {
    @StateObject private var store: ConversationStore
    @StateObject private var modelStore: ModelStore
    @StateObject private var viewModel: ChatViewModel
    @StateObject private var themeManager = ThemeManager.shared
    @State private var showOnboarding: Bool
    @State private var chatReady: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    init() {
        let convStore = ConversationStore()
        let mStore = ModelStore()
        _store = StateObject(wrappedValue: convStore)
        _modelStore = StateObject(wrappedValue: mStore)
        _viewModel = StateObject(wrappedValue: ChatViewModel(store: convStore, modelStore: mStore))
        _showOnboarding = State(initialValue: !KeychainHelper.hasAPIKey)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Warstwa 1: Chat (renderuje się zawsze pod spodem, ale pokazujemy splash aż będzie gotowy)
                Group {
                    if showOnboarding {
                        OnboardingView(isPresented: $showOnboarding)
                    } else {
                        ChatView(viewModel: viewModel)
                            .environmentObject(store)
                            .environmentObject(modelStore)
                            .environmentObject(themeManager)
                            .environmentObject(FolderStore.shared)
                            .environmentObject(PresetStore.shared)
                            .preferredColorScheme(preferredScheme)
                    }
                }
                .preferredColorScheme(preferredScheme)
                .opacity(chatReady ? 1 : 0)

                // Warstwa 2: Splash - widoczny aż chat się wyrenderuje
                if !chatReady {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .task {
                // Splash widoczny minimum 500ms + czekamy na pierwszy frame chatu
                // Dzięki temu splash jest ZANIM chat się pokaże, nie PO
                try? await Task.sleep(nanoseconds: 500_000_000)
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.4)) {
                        chatReady = true
                    }
                }
            }
            .task {
                // Prośba o pozwolenie na notyfikacje (raz, przy starcie)
                await NotificationManager.shared.requestAuthorizationIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: .openConversationRequested)) { notification in
                guard let convId = notification.userInfo?["conversationId"] as? UUID else { return }
                store.switchToConversation(id: convId)
            }
        }
    }

    private var preferredScheme: ColorScheme? {
        switch themeManager.mode {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil  // follow system
        }
    }
}

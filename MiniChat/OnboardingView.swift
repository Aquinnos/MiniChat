//
//  OnboardingView.swift
//  MiniChat
//
//  Ekran powitalny — pojawia się przy pierwszym uruchomieniu.
//

import SwiftUI

struct OnboardingView: View {
    @State private var apiKey: String = ""
    @State private var isSecure: Bool = true
    @State private var errorMessage: String?
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 30)

                    ZStack {
                        Circle()
                            .fill(Theme.gold.opacity(0.2))
                            .frame(width: 140, height: 140)
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(Theme.gold)
                    }

                    VStack(spacing: 8) {
                        Text("Witaj w MiniChat")
                            .font(.largeTitle.bold())
                            .foregroundColor(Theme.textPrimary)
                        Text("Twój osobisty asystent AI w kieszeni")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                    }
                    .multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: 12) {
                        Label("Streaming odpowiedzi", systemImage: "bolt.fill")
                        Label("Historia rozmów", systemImage: "clock.arrow.circlepath")
                        Label("Bezpieczne przechowywanie klucza w Keychain", systemImage: "lock.shield.fill")
                    }
                    .font(.callout)
                    .foregroundColor(Theme.textPrimary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Theme.gold.opacity(0.4), lineWidth: 1)
                    )
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Twój klucz API")
                            .font(.headline)
                            .foregroundColor(Theme.textPrimary)

                        HStack {
                            if isSecure {
                                SecureField("eyJhbGciOi...", text: $apiKey)
                            } else {
                                TextField("eyJhbGciOi...", text: $apiKey)
                                    #if os(iOS) && !targetEnvironment(macCatalyst)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    #endif
                            }
                            Button {
                                isSecure.toggle()
                            } label: {
                                Image(systemName: isSecure ? "eye" : "eye.slash")
                                    .foregroundColor(Theme.blue)
                            }
                        }
                        .padding(12)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.gold.opacity(0.4), lineWidth: 1)
                        )

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                        }

                        Text("Pobierz klucz na platform.minimax.io → Account → API Keys.")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding(.horizontal)

                    Button {
                        save()
                    } label: {
                        Text("Zaczynamy")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [Theme.blue, Theme.blue.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
                    .padding(.horizontal)

                    Spacer(minLength: 30)
                }
            }
            .background(Theme.background.ignoresSafeArea())
        }
    }

    private func save() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Wpisz klucz API"
            return
        }
        do {
            try KeychainHelper.save(trimmed)
            isPresented = false
        } catch {
            errorMessage = "Nie udało się zapisać: \(error.localizedDescription)"
        }
    }
}

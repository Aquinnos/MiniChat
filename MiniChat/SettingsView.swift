//
//  SettingsView.swift
//  MiniChat
//
//  Ustawienia — wpisywanie / zmiana API key.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var memoryStore = MemoryStore.shared
    @State private var apiKey: String = ""
    @State private var isSecure: Bool = true
    @State private var saveStatus: String?
    @State private var apiBaseURL: String = MiniMaxAPIClient.defaultBaseURL
    @State private var webSearchEnabled: Bool = UserDefaults.standard.bool(forKey: "webSearchEnabled")
    @State private var exaApiKey: String = ""
    @State private var newFactText: String = ""
    @State private var editingFact: MemoryFact?

    var body: some View {
        NavigationStack {
            Form {
                Section {
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
                } header: {
                    Text("MiniMax API Key")
                } footer: {
                    Text("Pobierz klucz na platform.minimax.io → Account → API Keys. Klucz jest przechowywany bezpiecznie w Keychain Twojego telefonu.")
                        .font(.caption)
                }

                Section {
                    HStack {
                        TextField("https://...", text: $apiBaseURL)
                            #if os(iOS) && !targetEnvironment(macCatalyst)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            #endif
                        Menu {
                            Button("api.minimaxi.com (domyślny)") {
                                apiBaseURL = MiniMaxAPIClient.defaultBaseURL
                            }
                            Button("api.minimax.io (alternatywny)") {
                                apiBaseURL = MiniMaxAPIClient.alternativeBaseURL
                            }
                        } label: {
                            Image(systemName: "list.bullet")
                                .foregroundColor(Theme.blue)
                        }
                    }
                } header: {
                    Text("URL API")
                } footer: {
                    Text("Jeśli masz problemy z połączeniem (błąd 'A server with the specified hostname could not be found'), spróbuj zmienić na alternatywny endpoint.")
                        .font(.caption)
                }

                // Web search - przeniesiony do menu "+" w input bar
                // M3 ma web search zawsze ON, dla innych modeli - toggle w plus menu

                // MARK: - Exa API key (optional - AI-native search)

                // MARK: - Exa API key (optional - AI-native search)
                Section {
                    HStack {
                        if isSecure {
                            SecureField("...", text: $exaApiKey)
                        } else {
                            TextField("...", text: $exaApiKey)
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
                    HStack {
                        Image(systemName: ExaSearcher.shared.isConfigured ? "checkmark.seal.fill" : "info.circle")
                            .foregroundColor(ExaSearcher.shared.isConfigured ? .green : .secondary)
                        Text(ExaSearcher.shared.isConfigured
                             ? "Exa Search aktywny — AI-native wyniki (semantyczne + highlights)"
                             : "Bez klucza — DuckDuckGo (słabsze dla trendów)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Exa Search API (opcjonalnie)")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Exa.ai to AI-native search — wyniki preprocesowane pod LLM (highlights, semantyka). Darmowy tier na start.")
                        Link("Pobierz klucz na dashboard.exa.ai", destination: URL(string: "https://dashboard.exa.ai/")!)
                    }
                    .font(.caption)
                }

                // MARK: - Memory section
                Section {
                    HStack {
                        TextField("Np. 'Jestem programistą iOS', 'Mieszkam w Gdyni'", text: $newFactText)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { addFact() }
                        Button {
                            addFact()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(Theme.blue)
                        }
                        .disabled(newFactText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    if !memoryStore.facts.isEmpty {
                        ForEach(memoryStore.facts) { fact in
                            HStack(alignment: .top) {
                                Image(systemName: "brain")
                                    .foregroundColor(Theme.gold)
                                    .frame(width: 24)
                                    .padding(.top, 2)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(fact.content)
                                        .font(.callout)
                                    Text(fact.createdAt, style: .date)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Menu {
                                    Button {
                                        editingFact = fact
                                    } label: {
                                        Label("Edytuj", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        memoryStore.remove(fact)
                                    } label: {
                                        Label("Usuń", systemImage: "trash")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .foregroundColor(Theme.textSecondary)
                                }
                            }
                        }
                    } else {
                        Text("Brak faktów. Dodaj rzeczy które model ma pamiętać między rozmowami.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    HStack {
                        Text("Pamięć")
                        Spacer()
                        if !memoryStore.facts.isEmpty {
                            Button(role: .destructive) {
                                memoryStore.clear()
                            } label: {
                                Text("Wyczyść")
                                    .font(.caption)
                            }
                        }
                    }
                } footer: {
                    Text("Te fakty będą widoczne dla modelu jako kontekst na początku każdej rozmowy.")
                        .font(.caption)
                }

                if let saveStatus {
                    Section {
                        Text(saveStatus)
                            .font(.callout)
                            .foregroundColor(saveStatus.contains("✅") ? .green : .red)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        KeychainHelper.delete()
                        apiKey = ""
                        saveStatus = "✅ Usunięto"
                    } label: {
                        Label("Usuń API key", systemImage: "trash")
                    }
                }

                Section {
                    Link(destination: URL(string: "https://platform.minimax.io/user-center/basic-information/interface-key")!) {
                        Label("Otwórz platform.minimax.io", systemImage: "link")
                    }
                } header: {
                    Text("Gdzie pobrać klucz?")
                }
            }
            .navigationTitle("Ustawienia")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zapisz") {
                        save()
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                apiKey = KeychainHelper.read() ?? ""
                apiBaseURL = UserDefaults.standard.string(forKey: "api_base_url") ?? MiniMaxAPIClient.defaultBaseURL
                exaApiKey = UserDefaults.standard.string(forKey: "exaApiKey") ?? ""
            }
        }
    }

    private func save() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = apiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedExa = exaApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try KeychainHelper.save(trimmed)
            UserDefaults.standard.set(trimmedURL, forKey: "api_base_url")
            UserDefaults.standard.set(webSearchEnabled, forKey: "webSearchEnabled")
            UserDefaults.standard.set(trimmedExa, forKey: "exaApiKey")
            saveStatus = "✅ Zapisano"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                dismiss()
            }
        } catch {
            saveStatus = "❌ Błąd: \(error.localizedDescription)"
        }
    }

    private func addFact() {
        let trimmed = newFactText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        memoryStore.add(trimmed)
        newFactText = ""
    }
}

#Preview {
    SettingsView()
}

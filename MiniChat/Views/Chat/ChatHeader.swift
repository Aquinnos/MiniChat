//
//  ChatHeader.swift
//  MiniChat
//
//  Górny pasek: historia, model+picker, preset, nowa rozmowa, ustawienia.
//

import SwiftUI

struct ChatHeader: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var presetStore: PresetStore
    let onShowHistory: () -> Void
    let onShowModelPicker: () -> Void
    let onShowPresets: () -> Void
    let onStartNewChat: () -> Void
    let onShowSettings: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onShowHistory) {
                Image(systemName: "line.3.horizontal")
                    .font(.title3)
                    .foregroundColor(Theme.blue)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            modelButton

            Button(action: onShowPresets) {
                Image(systemName: presetStore.selectedPreset == nil ? "slider.horizontal.3" : "checkmark.seal.fill")
                    .font(.title3)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
                    .foregroundColor(presetStore.selectedPreset == nil ? Theme.blue : Theme.gold)
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: onStartNewChat) {
                Image(systemName: "square.and.pencil")
                    .font(.title3)
                    .foregroundColor(Theme.blue)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onShowSettings) {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .foregroundColor(Theme.blue)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.surface)
    }

    private var modelButton: some View {
        Button(action: onShowModelPicker) {
            VStack(spacing: 0) {
                Text("MiniChat")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                HStack(spacing: 4) {
                    Image(systemName: "cpu").font(.caption2)
                    Text(viewModel.selectedModel.displayName).font(.caption2)
                    if viewModel.selectedModel.supportsAttachments {
                        Image(systemName: "paperclip").font(.caption2)
                    }
                    Image(systemName: "chevron.down").font(.caption2)
                }
                .foregroundColor(Theme.blue)
            }
        }
        .buttonStyle(.plain)
    }
}

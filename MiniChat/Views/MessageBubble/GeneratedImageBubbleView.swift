//
//  GeneratedImageBubbleView.swift
//  MiniChat
//
//  Obraz wygenerowany przez model (image generation tool).
//  Z akcjami: zapisz do zdjęć, kopiuj.
//

import SwiftUI
import UIKit

struct GeneratedImageBubbleView: View {
    let image: GeneratedImage

    var body: some View {
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
                        if let pngData = uiImage.pngData(),
                           let saved = UIImage(data: pngData) {
                            UIImageWriteToSavedPhotosAlbum(saved, nil, nil, nil)
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

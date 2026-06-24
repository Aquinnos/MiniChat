//
//  AttachmentThumb.swift
//  MiniChat
//
//  Pojedynczy thumbnail załącznika: obrazek lub placeholder pliku z ikoną.
//

import SwiftUI
import UIKit

struct AttachmentThumb: View {
    let attachment: Attachment

    var body: some View {
        if attachment.isImage, let base64 = attachment.base64Data,
           let data = Data(base64Encoded: base64),
           let uiImage = UIImage(data: data) {
            imageContent(uiImage)
        } else {
            filePlaceholder
        }
    }

    private func imageContent(_ uiImage: UIImage) -> some View {
        Image(uiImage: uiImage)
            .resizable()
            .scaledToFill()
            .frame(width: 90, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var filePlaceholder: some View {
        VStack(spacing: 4) {
            Image(systemName: Self.fileIcon(for: attachment.mimeType))
                .font(.system(size: 24))
                .foregroundColor(.white)
            Text(attachment.fileName)
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

    static func fileIcon(for mimeType: String) -> String {
        if mimeType.hasPrefix("text/") { return "doc.text" }
        if mimeType.contains("pdf") { return "doc.richtext" }
        if mimeType.contains("json") { return "curlybraces" }
        if mimeType.contains("csv") { return "tablecells" }
        if mimeType.contains("zip") || mimeType.contains("archive") { return "doc.zipper" }
        return "doc.fill"
    }
}

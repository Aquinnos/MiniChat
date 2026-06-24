//
//  PendingAttachmentsBar.swift
//  MiniChat
//
//  Poziomy pasek miniatur załączników czekających na wysłanie (nad input barem).
//

import SwiftUI
import UIKit

struct PendingAttachmentsBar: View {
    let attachments: [Attachment]
    let onRemove: (Attachment) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(attachments) { attachment in
                    chip(for: attachment)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Theme.surface.opacity(0.5))
    }

    private func chip(for attachment: Attachment) -> some View {
        HStack(spacing: 6) {
            if attachment.isImage, let base64 = attachment.base64Data,
               let data = Data(base64Encoded: base64),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: "doc.fill")
                    .foregroundColor(Theme.blue)
            }
            Text(attachment.fileName)
                .font(.caption)
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
            Button {
                onRemove(attachment)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Theme.goldSoft.opacity(0.5))
        .clipShape(Capsule())
    }
}

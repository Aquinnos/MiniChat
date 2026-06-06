//
//  DocumentPicker.swift
//  MiniChat
//
//  UIKit wrapper dla UIDocumentPickerViewController.
//

import SwiftUI
import UniformTypeIdentifiers
import PDFKit

struct DocumentPicker: UIViewControllerRepresentable {
    let allowedTypes: [UTType]
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedTypes, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker

        init(_ parent: DocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.onPick(url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {}
    }
}

// MARK: - Plik → Attachment helper

enum AttachmentBuilder {
    /// Tworzy Attachment z URL pliku
    static func build(from url: URL) -> Attachment? {
        let fileName = url.lastPathComponent
        let ext = url.pathExtension.lowercased()
        let mimeType = UTType(filenameExtension: ext)?.preferredMIMEType ?? "application/octet-stream"

        // Bezpieczny dostęp do pliku (iOS używa security-scoped URLs)
        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }

        // PDF - wyciągnij tekst przez PDFKit (bez ładowania całego pliku do pamięci)
        if ext == "pdf" || mimeType == "application/pdf" {
            if let pdfDoc = PDFDocument(url: url) {
                let pageCount = pdfDoc.pageCount
                var fullText = ""
                let maxPages = min(pageCount, 50)  // max 50 stron
                for i in 0..<maxPages {
                    if let page = pdfDoc.page(at: i), let text = page.string {
                        fullText += "=== Strona \(i + 1) z \(pageCount) ===\n\(text)\n\n"
                    }
                }
                if !fullText.isEmpty {
                    let truncated = String(fullText.prefix(50_000))
                    return Attachment(
                        type: .file,
                        mimeType: mimeType,
                        fileName: fileName,
                        base64Data: nil,
                        textContent: truncated
                    )
                }
            }
        }

        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        // Pliki tekstowe - czytaj jako tekst
        let isText = mimeType.hasPrefix("text/") ||
                     ["json", "csv", "xml", "md", "swift", "py", "js", "ts", "html", "css", "yaml", "yml", "log", "ini", "toml", "sh", "bash"]
                        .contains(ext)

        if isText {
            if let text = String(data: data, encoding: .utf8) {
                // Limit do 50kB tekstu żeby nie przeciążyć API
                let truncated = String(text.prefix(50_000))
                return Attachment(
                    type: .file,
                    mimeType: mimeType,
                    fileName: fileName,
                    base64Data: nil,
                    textContent: truncated
                )
            }
        }

        // Pliki binarne / obrazy - jako base64
        // Limit do 10 MB
        if data.count > 10 * 1024 * 1024 {
            return nil
        }

        return Attachment(
            type: mimeType.hasPrefix("image/") ? .image : .file,
            mimeType: mimeType,
            fileName: fileName,
            base64Data: data.base64EncodedString(),
            textContent: nil
        )
    }
}

import AppKit
import Foundation
import UniformTypeIdentifiers

enum ImageFileExporter {
    static func defaultFileName(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "Snaplingo-\(formatter.string(from: now)).png"
    }

    static func pngData(from image: NSImage) throws -> Data {
        var proposedRect = CGRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else {
            throw AppError.imageConversionFailed
        }

        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        bitmap.size = image.size
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw AppError.imageConversionFailed
        }
        return data
    }

    static func writePNG(_ image: NSImage, to url: URL) throws {
        try pngData(from: image).write(to: url, options: .atomic)
    }

    @MainActor
    static func promptAndWritePNG(_ image: NSImage) throws -> Bool {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = defaultFileName()

        guard panel.runModal() == .OK, let url = panel.url else {
            return false
        }

        try writePNG(image, to: url)
        return true
    }
}

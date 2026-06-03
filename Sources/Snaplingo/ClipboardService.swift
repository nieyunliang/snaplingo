import AppKit

protocol ClipboardServicing {
    func copyImage(_ image: NSImage)
}

struct ClipboardService: ClipboardServicing {
    func copyImage(_ image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }
}

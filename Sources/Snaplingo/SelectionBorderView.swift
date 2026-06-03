import AppKit
import SwiftUI

final class SelectionBorderView: NSView {
    var selection: CGRect? {
        didSet {
            isHidden = selection == nil
            needsDisplay = true
        }
    }

    init(selection: CGRect? = nil) {
        self.selection = selection
        super.init(frame: .zero)
        isHidden = selection == nil
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isOpaque: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let selection else { return }
        SelectionOverlayRenderer.drawSelectionChrome(in: selection)
    }
}

struct SelectionBorderRepresentable: NSViewRepresentable {
    let selection: CGRect?

    func makeNSView(context: Context) -> SelectionBorderView {
        SelectionBorderView(selection: selection)
    }

    func updateNSView(_ nsView: SelectionBorderView, context: Context) {
        nsView.selection = selection
    }
}

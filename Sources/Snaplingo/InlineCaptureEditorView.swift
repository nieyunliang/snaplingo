import SwiftUI

struct InlineCaptureEditorView: View {
    @ObservedObject var document: InlineCaptureDocument
    let screenshotFrame: CGRect
    let toolbarFrame: CGRect
    let close: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            InlineCaptureCanvas(document: document)
                .frame(width: screenshotFrame.width, height: screenshotFrame.height)
                .position(x: screenshotFrame.midX, y: screenshotFrame.midY)

            ScreenshotToolbar(document: document, close: close)
                .frame(width: toolbarFrame.width, height: toolbarFrame.height)
                .position(x: toolbarFrame.midX, y: toolbarFrame.midY)
        }
        .frame(
            width: max(screenshotFrame.maxX, toolbarFrame.maxX),
            height: max(screenshotFrame.maxY, toolbarFrame.maxY),
            alignment: .topLeading
        )
    }
}

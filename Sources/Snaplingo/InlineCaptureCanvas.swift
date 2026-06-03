import AppKit
import SwiftUI

struct InlineCaptureCanvas: View {
    @ObservedObject var document: InlineCaptureDocument

    var body: some View {
        GeometryReader { proxy in
            let imageRect = CGRect(origin: .zero, size: proxy.size)
            ZStack(alignment: .topLeading) {
                Image(nsImage: document.renderedImage())
                    .resizable()
                    .frame(width: proxy.size.width, height: proxy.size.height)

                Canvas { context, _ in
                    guard let draft = document.draftAnnotation else { return }
                    context.withCGContext { cgContext in
                        NSGraphicsContext.saveGraphicsState()
                        NSGraphicsContext.current = NSGraphicsContext(cgContext: cgContext, flipped: false)
                        AnnotationRenderer.drawPreview(draft, in: imageRect, imageSize: document.screenshot.image.size)
                        NSGraphicsContext.restoreGraphicsState()
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .contentShape(Rectangle())
                .allowsHitTesting(document.drawingTool != nil)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let point = imagePoint(from: value.location, viewSize: proxy.size)
                            if document.draftAnnotation == nil {
                                document.beginDrawing(at: point)
                            } else {
                                document.dragDrawing(to: point)
                            }
                        }
                        .onEnded { value in
                            document.endDrawing(at: imagePoint(from: value.location, viewSize: proxy.size))
                        }
                )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .overlay {
                Rectangle()
                    .stroke(Color.accentColor, lineWidth: 2)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
        }
    }

    private func imagePoint(from point: CGPoint, viewSize: CGSize) -> CGPoint {
        guard viewSize.width > 0, viewSize.height > 0 else {
            return .zero
        }
        return CGPoint(
            x: point.x / viewSize.width * document.screenshot.image.size.width,
            y: point.y / viewSize.height * document.screenshot.image.size.height
        )
    }
}

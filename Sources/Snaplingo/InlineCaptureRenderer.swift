import AppKit

enum InlineCaptureRenderer {
    static func render(image: NSImage, annotations: [AnnotationItem], patches: [InlineTranslationPatch]) -> NSImage {
        let startedAt = PerformanceMetrics.start()
        let translated = NSImage(size: image.size)
        translated.lockFocus()
        image.draw(in: CGRect(origin: .zero, size: image.size))
        for patch in patches {
            draw(patch, imageSize: image.size)
        }
        translated.unlockFocus()
        let rendered = AnnotationRenderer.render(image: translated, annotations: annotations)
        PerformanceMetrics.log(
            "inline_render",
            since: startedAt,
            metadata: "patches=\(patches.count) annotations=\(annotations.count) width=\(Int(image.size.width)) height=\(Int(image.size.height))"
        )
        return rendered
    }

    private static func draw(_ patch: InlineTranslationPatch, imageSize: CGSize) {
        let topLeftRect = patch.imageRect.standardized.insetBy(dx: -4, dy: -3)
        let rect = CGRect(
            x: topLeftRect.minX,
            y: imageSize.height - topLeftRect.maxY,
            width: topLeftRect.width,
            height: topLeftRect.height
        ).intersection(CGRect(origin: .zero, size: imageSize))
        guard rect.width > 2, rect.height > 2 else {
            return
        }

        NSColor.white.withAlphaComponent(0.88).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        paragraph.alignment = .left
        let fontSize = fittedFontSize(for: patch.translatedText, in: rect, paragraph: paragraph)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: NSColor.black,
            .paragraphStyle: paragraph
        ]
        (patch.translatedText as NSString).draw(
            with: rect.insetBy(dx: 3, dy: 2),
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: attributes
        )
    }

    private static func fittedFontSize(for text: String, in rect: CGRect, paragraph: NSParagraphStyle) -> CGFloat {
        for size in stride(from: min(20, max(10, rect.height * 0.76)), through: 8, by: -1) {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: size, weight: .medium),
                .paragraphStyle: paragraph
            ]
            let measured = (text as NSString).boundingRect(
                with: rect.insetBy(dx: 3, dy: 2).size,
                options: [.usesLineFragmentOrigin],
                attributes: attributes
            )
            if measured.height <= rect.height - 4 {
                return size
            }
        }
        return 8
    }
}

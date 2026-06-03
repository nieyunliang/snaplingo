import AppKit
import XCTest
@testable import Snaplingo

final class RendererTests: XCTestCase {
    func testAnnotationRendererTreatsRectsAsTopLeftImageCoordinates() throws {
        let image = NSImage(size: CGSize(width: 40, height: 40))
        image.lockFocus()
        NSColor.black.setFill()
        CGRect(x: 0, y: 0, width: 40, height: 40).fill()
        image.unlockFocus()

        let rendered = AnnotationRenderer.render(
            image: image,
            annotations: [
                AnnotationItem(
                    tool: .rectangle,
                    rect: CGRect(x: 0, y: 0, width: 40, height: 16),
                    colorHex: "#FFFFFF",
                    lineWidth: 4
                )
            ]
        )

        let cgImage = try XCTUnwrap(rendered.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let topEnergy = cgImage.pixelEnergy(row: 34)
        let bottomEnergy = cgImage.pixelEnergy(row: 4)
        XCTAssertGreaterThan(topEnergy, bottomEnergy)
    }

    func testAnnotationRendererDrawsCircleWithoutPaintingBoundingBoxCorners() throws {
        let image = makeSolidImage(.black, size: CGSize(width: 40, height: 40))
        let rendered = AnnotationRenderer.render(
            image: image,
            annotations: [
                AnnotationItem(
                    tool: .circle,
                    rect: CGRect(x: 4, y: 4, width: 32, height: 32),
                    colorHex: "#FFFFFF",
                    lineWidth: 4
                )
            ]
        )

        let cgImage = try XCTUnwrap(rendered.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let centerEdgeEnergy = max(
            cgImage.maximumPixelEnergy(in: CGRect(x: 16, y: 0, width: 8, height: 40)),
            cgImage.maximumPixelEnergy(in: CGRect(x: 0, y: 16, width: 40, height: 8))
        )
        let cornerEnergy = max(
            cgImage.maximumPixelEnergy(in: CGRect(x: 0, y: 0, width: 4, height: 4)),
            cgImage.maximumPixelEnergy(in: CGRect(x: 36, y: 0, width: 4, height: 4)),
            cgImage.maximumPixelEnergy(in: CGRect(x: 0, y: 36, width: 4, height: 4)),
            cgImage.maximumPixelEnergy(in: CGRect(x: 36, y: 36, width: 4, height: 4))
        )
        XCTAssertGreaterThan(centerEdgeEnergy, 500)
        XCTAssertLessThan(cornerEnergy, 100)
    }

    func testAnnotationRendererStopsArrowShaftInsideArrowhead() {
        let end = CGPoint(x: 90, y: 20)
        let shaftEnd = AnnotationRenderer.arrowShaftEnd(
            from: CGPoint(x: 10, y: 20),
            to: end,
            headLength: 14,
            headAngle: .pi / 7,
            width: 3
        )

        XCTAssertLessThan(shaftEnd.x, end.x)
        XCTAssertGreaterThan(shaftEnd.x, end.x - 14)
        XCTAssertEqual(shaftEnd.y, end.y, accuracy: 0.001)
    }

    func testAnnotationItemDefaultsToRed() {
        let annotation = AnnotationItem(tool: .rectangle, rect: .zero)

        XCTAssertEqual(annotation.colorHex, "#FF3B30")
    }

    func testImageFileExporterCreatesDecodablePNGData() throws {
        let image = makeSolidImage(.systemBlue, size: CGSize(width: 12, height: 8))

        let data = try ImageFileExporter.pngData(from: image)

        XCTAssertEqual(Array(data.prefix(8)), [137, 80, 78, 71, 13, 10, 26, 10])
        let decoded = try XCTUnwrap(NSBitmapImageRep(data: data))
        XCTAssertGreaterThanOrEqual(decoded.pixelsWide, 12)
        XCTAssertGreaterThanOrEqual(decoded.pixelsHigh, 8)
        XCTAssertEqual(Double(decoded.pixelsWide) / Double(decoded.pixelsHigh), 1.5, accuracy: 0.01)
    }
}

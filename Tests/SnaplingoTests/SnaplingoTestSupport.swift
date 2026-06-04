import AppKit
import XCTest
@testable import Snaplingo

func makeTextImage(_ text: String) -> NSImage {
    let image = NSImage(size: CGSize(width: 1200, height: 320))
    image.lockFocus()
    NSColor.white.setFill()
    CGRect(x: 0, y: 0, width: 1200, height: 320).fill()
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.boldSystemFont(ofSize: 96),
        .foregroundColor: NSColor.black
    ]
    (text as NSString).draw(in: CGRect(x: 48, y: 104, width: 1100, height: 140), withAttributes: attributes)
    image.unlockFocus()
    return image
}

func makeSolidImage(_ color: NSColor, size: CGSize = CGSize(width: 20, height: 20)) -> NSImage {
    let image = NSImage(size: size)
    image.lockFocus()
    color.setFill()
    CGRect(origin: .zero, size: size).fill()
    image.unlockFocus()
    return image
}

@MainActor
func makeTranslationMemoryStore() -> TranslationMemoryStore {
    TranslationMemoryStore(
        fileURL: URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("memory-\(UUID().uuidString).json")
    )
}

extension CGImage {
    func pixelEnergy(row: Int) -> Int {
        let sampler = BitmapEnergySampler(cgImage: self)
        let clampedRow = min(max(row, 0), height - 1)
        var total = 0
        for x in 0 ..< width {
            total += sampler.energyAt(x: x, y: clampedRow)
        }
        return total / max(1, width)
    }

    func maximumPixelEnergy(in rect: CGRect) -> Int {
        guard !rect.isEmpty else {
            return 0
        }

        let sampler = BitmapEnergySampler(cgImage: self)
        let minX = min(max(Int(rect.minX.rounded(.down)), 0), width - 1)
        let maxX = min(max(Int(rect.maxX.rounded(.up)) - 1, 0), width - 1)
        let minY = min(max(Int(rect.minY.rounded(.down)), 0), height - 1)
        let maxY = min(max(Int(rect.maxY.rounded(.up)) - 1, 0), height - 1)
        guard minX <= maxX, minY <= maxY else {
            return 0
        }

        var maximum = 0
        for y in minY ... maxY {
            for x in minX ... maxX {
                maximum = max(maximum, sampler.energyAt(x: x, y: y))
            }
        }
        return maximum
    }
}

private struct BitmapEnergySampler {
    private let bitmap: NSBitmapImageRep

    init(cgImage: CGImage) {
        bitmap = NSBitmapImageRep(cgImage: cgImage)
    }

    func energyAt(x: Int, y: Int) -> Int {
        guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
            return 0
        }
        return Int((color.redComponent * 255).rounded())
            + Int((color.greenComponent * 255).rounded())
            + Int((color.blueComponent * 255).rounded())
    }
}

final class HTTPDataLoaderStub: HTTPDataLoading {
    private let data: Data
    private let statusCode: Int
    private(set) var requests: [URLRequest] = []

    init(data: Data, statusCode: Int) {
        self.data = data
        self.statusCode = statusCode
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://unit.test")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (data, response)
    }
}

@MainActor
final class OCRServiceStub: OCRServicing {
    private(set) var requestCount = 0
    private let result: OCRResult

    init(result: OCRResult) {
        self.result = result
    }

    func recognize(image: NSImage, languages: [String]) async throws -> OCRResult {
        requestCount += 1
        return result
    }
}

@MainActor
final class CancellableOCRServiceStub: OCRServicing {
    private(set) var requestCount = 0
    private var continuation: CheckedContinuation<Void, Never>?
    private let result: OCRResult

    init(result: OCRResult) {
        self.result = result
    }

    func recognize(image: NSImage, languages: [String]) async throws -> OCRResult {
        requestCount += 1
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
        if Task.isCancelled {
            throw CancellationError()
        }
        return result
    }

    func resume() {
        continuation?.resume()
        continuation = nil
    }
}

struct ClipboardServiceStub: ClipboardServicing {
    func copyImage(_ image: NSImage) {}
}

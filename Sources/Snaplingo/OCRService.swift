import AppKit
@preconcurrency import Vision

@MainActor
protocol OCRServicing {
    func recognize(image: NSImage, languages: [String]) async throws -> OCRResult
}

@MainActor
struct VisionOCRService: OCRServicing {
    func recognize(image: NSImage, languages: [String]) async throws -> OCRResult {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw AppError.imageConversionFailed
        }

        return try await VisionOCRRunner.recognize(cgImage: cgImage, languages: languages)
    }
}

private enum VisionOCRRunner {
    static func recognize(cgImage: CGImage, languages: [String]) async throws -> OCRResult {
        do {
            let fastResult = try await timedRecognition(
                cgImage: cgImage,
                languages: languages,
                recognitionLevel: .fast,
                usesLanguageCorrection: false,
                metricName: "vision_ocr_fast"
            )
            guard OCRRecognitionStrategy.shouldRetryAccurately(fastResult: fastResult) else {
                return fastResult
            }
        } catch AppError.noTextRecognized {
            // Accurate recognition below is the fallback for an empty fast pass.
        }

        do {
            return try await timedRecognition(
                cgImage: cgImage,
                languages: languages,
                recognitionLevel: .accurate,
                usesLanguageCorrection: true,
                metricName: "vision_ocr_accurate"
            )
        } catch AppError.noTextRecognized where !languages.isEmpty {
            return try await timedRecognition(
                cgImage: cgImage,
                languages: [],
                recognitionLevel: .accurate,
                usesLanguageCorrection: true,
                metricName: "vision_ocr_accurate_auto_language"
            )
        }
    }

    private static func timedRecognition(
        cgImage: CGImage,
        languages: [String],
        recognitionLevel: VNRequestTextRecognitionLevel,
        usesLanguageCorrection: Bool,
        metricName: String
    ) async throws -> OCRResult {
        let startedAt = PerformanceMetrics.start()
        do {
            let result = try await performRecognition(
                cgImage: cgImage,
                languages: languages,
                recognitionLevel: recognitionLevel,
                usesLanguageCorrection: usesLanguageCorrection
            )
            PerformanceMetrics.log(metricName, since: startedAt, metadata: "blocks=\(result.blocks.count)")
            return result
        } catch {
            PerformanceMetrics.log(metricName, since: startedAt, metadata: "outcome=error")
            throw error
        }
    }

    private static func performRecognition(
        cgImage: CGImage,
        languages: [String],
        recognitionLevel: VNRequestTextRecognitionLevel,
        usesLanguageCorrection: Bool
    ) async throws -> OCRResult {
        return try await withCheckedThrowingContinuation { continuation in
            let continuationBox = OCRContinuationBox(continuation)
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuationBox.resume(throwing: error)
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let blocks = observations.compactMap { observation -> OCRTextBlock? in
                    guard let candidate = observation.topCandidates(1).first else {
                        return nil
                    }
                    return OCRTextBlock(
                        text: candidate.string,
                        boundingBox: observation.boundingBox,
                        confidence: Double(candidate.confidence)
                    )
                }

                let text = blocks.map(\.text).joined(separator: "\n")
                guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    continuationBox.resume(throwing: AppError.noTextRecognized)
                    return
                }

                let confidences = blocks.compactMap(\.confidence)
                let average = confidences.isEmpty
                    ? nil
                    : confidences.reduce(0, +) / Double(confidences.count)

                continuationBox.resume(returning: OCRResult(
                    text: text,
                    confidence: average,
                    blocks: blocks
                ))
            }

            request.recognitionLevel = recognitionLevel
            request.usesLanguageCorrection = usesLanguageCorrection
            let supportedLanguages = Self.supportedLanguages(from: languages, for: request)
            request.recognitionLanguages = supportedLanguages
            request.automaticallyDetectsLanguage = supportedLanguages.isEmpty

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                    try handler.perform([request])
                } catch {
                    continuationBox.resume(throwing: error)
                }
            }
        }
    }

    private static func supportedLanguages(from languages: [String], for request: VNRecognizeTextRequest) -> [String] {
        guard !languages.isEmpty,
              let supported = try? request.supportedRecognitionLanguages()
        else {
            return languages
        }

        return languages.compactMap { language in
            if supported.contains(language) {
                return language
            }

            let languageCode = Locale(identifier: language).language.languageCode?.identifier
            if let languageCode, supported.contains(languageCode) {
                return languageCode
            }

            return nil
        }
    }
}

enum OCRRecognitionStrategy {
    static let minimumFastConfidence = 0.65

    static func shouldRetryAccurately(fastResult: OCRResult) -> Bool {
        guard let confidence = fastResult.confidence else {
            return true
        }
        return confidence < minimumFastConfidence
    }
}

private final class OCRContinuationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<OCRResult, Error>?

    init(_ continuation: CheckedContinuation<OCRResult, Error>) {
        self.continuation = continuation
    }

    func resume(returning result: OCRResult) {
        takeContinuation()?.resume(returning: result)
    }

    func resume(throwing error: Error) {
        takeContinuation()?.resume(throwing: error)
    }

    private func takeContinuation() -> CheckedContinuation<OCRResult, Error>? {
        lock.lock()
        defer { lock.unlock() }
        let continuation = continuation
        self.continuation = nil
        return continuation
    }
}

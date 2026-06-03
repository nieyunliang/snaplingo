import AppKit
import CoreGraphics
import ScreenCaptureKit

@MainActor
struct ScreenCaptureService {
    func listCapturableWindows() async throws -> [WindowCaptureCandidate] {
        try await withScreenCapturePermissionMapping {
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
            return content.windows
                .filter { window in
                    window.windowLayer == 0
                        && window.isOnScreen
                        && window.frame.width > 20
                        && window.frame.height > 20
                        && window.owningApplication?.processID != ProcessInfo.processInfo.processIdentifier
                }
                .map { window in
                    WindowCaptureCandidate(
                        id: window.windowID,
                        frame: window.frame
                    )
                }
        }
    }

    func capture(
        selection: CaptureSelection,
        includeWindowShadow: Bool = false
    ) async throws -> ScreenshotResult {
        switch selection {
        case .region(let displayID, let appKitRect):
            return try await captureRegion(displayID: displayID, appKitRect: appKitRect)
        case .window(let candidate):
            return try await captureWindow(id: candidate.id, includeShadow: includeWindowShadow)
        }
    }

    func captureRegion(
        displayID: CGDirectDisplayID,
        appKitRect: CGRect
    ) async throws -> ScreenshotResult {
        try await withScreenCapturePermissionMapping {
            let cgImage = try await captureDisplayImage(
                in: appKitRect,
                displayID: displayID
            )

            let image = NSImage(cgImage: cgImage, size: appKitRect.size)
            return ScreenshotResult(
                image: image,
                screenRect: appKitRect
            )
        }
    }

    func captureWindow(id: CGWindowID, includeShadow: Bool = false) async throws -> ScreenshotResult {
        try await withScreenCapturePermissionMapping {
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
            guard let window = content.windows.first(where: { $0.windowID == id }) else {
                throw AppError.noWindowFound
            }

            let rect = CaptureCoordinateConverter.appKitRect(
                fromDisplaySpace: window.frame,
                primaryAppKitFrame: NSScreen.primaryFrame
            )
            let scale = screenScale(for: rect)
            let filter = SCContentFilter(desktopIndependentWindow: window)
            let configuration = screenshotConfiguration(size: window.frame.size, scale: scale)
            configuration.ignoreShadowsSingleWindow = !includeShadow
            let cgImage = try await captureImage(contentFilter: filter, configuration: configuration)
            let image = NSImage(cgImage: cgImage, size: rect.size)
            return ScreenshotResult(
                image: image,
                screenRect: rect
            )
        }
    }

    private func withScreenCapturePermissionMapping<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch {
            throw PermissionGuide.mapScreenCaptureError(error)
        }
    }

    private func captureDisplayImage(in rect: CGRect, displayID: CGDirectDisplayID) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw AppError.captureFailed
        }

        let scale = screenScale(for: rect)
        let currentProcessID = ProcessInfo.processInfo.processIdentifier
        let appWindows = content.windows.filter {
            $0.owningApplication?.processID == currentProcessID
        }
        let filter = SCContentFilter(display: display, excludingWindows: appWindows)
        if #available(macOS 14.2, *) {
            filter.includeMenuBar = true
        }

        let localRect = CaptureCoordinateConverter.displayLocalRect(
            fromAppKit: rect,
            displaySpaceFrame: display.frame,
            primaryAppKitFrame: NSScreen.primaryFrame
        )
        let configuration = screenshotConfiguration(size: rect.size, scale: scale)
        configuration.sourceRect = localRect
        configuration.ignoreShadowsDisplay = true
        return try await captureImage(contentFilter: filter, configuration: configuration)
    }

    private func captureImage(contentFilter: SCContentFilter, configuration: SCStreamConfiguration) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureImage(contentFilter: contentFilter, configuration: configuration) { cgImage, error in
                resume(continuation, with: cgImage, error: error)
            }
        }
    }

    private func screenshotConfiguration(size: CGSize, scale: CGFloat) -> SCStreamConfiguration {
        let configuration = SCStreamConfiguration()
        configuration.width = max(1, Int(size.width * scale))
        configuration.height = max(1, Int(size.height * scale))
        configuration.showsCursor = false
        configuration.captureResolution = .best
        return configuration
    }

    private func screenScale(for rect: CGRect) -> CGFloat {
        NSScreen.screens.bestMatch(for: rect)?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
    }
}

struct WindowCaptureCandidate {
    let id: CGWindowID
    let frame: CGRect

    func appKitFrame(primaryFrame: CGRect = NSScreen.primaryFrame) -> CGRect {
        CaptureCoordinateConverter.appKitRect(fromDisplaySpace: frame, primaryAppKitFrame: primaryFrame)
    }
}

private func resume(
    _ continuation: CheckedContinuation<CGImage, Error>,
    with cgImage: CGImage?,
    error: Error?
) {
    if let cgImage {
        continuation.resume(returning: cgImage)
    } else if let error {
        continuation.resume(throwing: error)
    } else {
        continuation.resume(throwing: AppError.captureFailed)
    }
}

private extension Array where Element == NSScreen {
    func bestMatch(for rect: CGRect) -> NSScreen? {
        self.max { lhs, rhs in
            SelectionGeometry.intersectionArea(of: lhs.frame, with: rect)
                < SelectionGeometry.intersectionArea(of: rhs.frame, with: rect)
        }
    }
}

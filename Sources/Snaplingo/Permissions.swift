import AppKit
import CoreGraphics
import ScreenCaptureKit

enum PermissionGuide {
    static var hasScreenRecordingPermission: Bool {
        CGPreflightScreenCaptureAccess()
    }

    @discardableResult
    static func requestScreenRecordingPermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    static func openScreenRecordingSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
        if let url {
            NSWorkspace.shared.open(url)
        }
    }

    static func isScreenCapturePermissionError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == SCStreamErrorDomain, nsError.code == SCStreamError.userDeclined.rawValue {
            return true
        }

        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error,
           isScreenCapturePermissionError(underlying) {
            return true
        }

        let messages = [
            nsError.localizedDescription,
            nsError.localizedFailureReason,
            nsError.localizedRecoverySuggestion
        ]
            .compactMap(\.self)
            .joined(separator: " ")
            .lowercased()

        let authorizationFailurePhrases = [
            "not authorized",
            "not authorised",
            "permission denied",
            "permission required",
            "requires permission",
            "missing permission",
            "access denied",
            "user declined",
            "not permitted"
        ]

        return authorizationFailurePhrases.contains { messages.contains($0) }
    }

    static func mapScreenCaptureError(_ error: Error) -> Error {
        isScreenCapturePermissionError(error) ? AppError.screenRecordingDenied : error
    }
}

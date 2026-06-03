import Foundation
import OSLog

enum PerformanceMetrics {
    private static let logger = Logger(subsystem: "com.snaplingo.app", category: "performance")

    static func start() -> TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }

    static func log(_ event: String, since startedAt: TimeInterval, metadata: String = "") {
        let milliseconds = (ProcessInfo.processInfo.systemUptime - startedAt) * 1_000
        logger.info("\(event, privacy: .public) duration_ms=\(milliseconds, privacy: .public) \(metadata, privacy: .public)")
    }

    static func log(_ event: String, metadata: String = "") {
        logger.info("\(event, privacy: .public) \(metadata, privacy: .public)")
    }
}

import Foundation

/// One usage window, such as a 5-hour or weekly limit.
public struct QuotaWindow: Identifiable, Equatable {
    public let id: String
    public let title: String
    /// Percentage remaining, 0–100, or nil when the service didn't report usage.
    public let remaining: Double?
    public let reset: Date?

    public init(id: String, title: String, remaining: Double?, reset: Date?) {
        self.id = id
        self.title = title
        self.remaining = remaining
        self.reset = reset
    }
}

public struct QuotaResult: Equatable {
    public var windows: [QuotaWindow]
    public var plan: String?

    public init(windows: [QuotaWindow], plan: String?) {
        self.windows = windows
        self.plan = plan
    }
}

public struct QuotaError: LocalizedError, Equatable {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}

/// Converts a reported "percent used" into percent remaining, clamped to 0–100. Missing or nonfinite values stay unavailable.
func remainingPercent(used value: Any?) -> Double? {
    guard let used = (value as? NSNumber)?.doubleValue, used.isFinite else { return nil }
    return min(100, max(0, 100 - used))
}

func findExecutable(_ candidates: [String?]) -> String? {
    candidates.compactMap { $0 }.first { FileManager.default.isExecutableFile(atPath: $0) }
}

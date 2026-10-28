import Foundation

/// Reads ChatGPT plan rate limits through the signed-in Codex CLI (`codex app-server`, `account/rateLimits/read`).
public enum CodexQuota {
    public static func fetch() throws -> QuotaResult {
        let home = FileManager.default.homeDirectoryForCurrentUser
        guard let executable = findExecutable([ProcessInfo.processInfo.environment["CODEX_BINARY"],
            home.appendingPathComponent(".local/bin/codex").path,
            "/opt/homebrew/bin/codex", "/usr/local/bin/codex",
            "/Applications/Codex.app/Contents/Resources/codex"]) else {
            throw QuotaError("Codex CLI not found. Install Codex CLI, then reopen this app.")
        }
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        let initialize: [String: Any] = ["id": 1, "method": "initialize",
            "params": ["clientInfo": ["name": "quota_float", "title": "Quota Float", "version": version]]]
        return try exchangeJSONLines(executable: executable, arguments: ["app-server"], first: initialize, service: "Codex",
                                     unreachable: "Couldn’t reach Codex. Check your connection and ‘codex login’, then refresh.") { message, send in
            guard let id = message["id"] as? Int else { return nil }
            if let error = message["error"] as? [String: Any] {
                throw QuotaError((error["message"] as? String) ?? "Unable to read quota.")
            }
            if id == 1 {
                try send(["method": "initialized", "params": [:]])
                try send(["id": 2, "method": "account/rateLimits/read"])
            } else if id == 2, let result = message["result"] as? [String: Any] {
                let parsed = parse(result)
                guard !parsed.windows.isEmpty else { throw QuotaError("Quota unavailable. Sign in with ChatGPT using ‘codex login’.") }
                return parsed
            }
            return nil
        }
    }

    /// Parses an `account/rateLimits/read` result. Prefers per-bucket `rateLimitsByLimitId`, falling back to `rateLimits`.
    public static func parse(_ result: [String: Any]) -> QuotaResult {
        let buckets = result["rateLimitsByLimitId"] as? [String: [String: Any]] ?? [:]
        let entries: [(String, [String: Any])] = !buckets.isEmpty
            ? buckets.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
            : (result["rateLimits"] as? [String: Any]).map { [(($0["limitId"] as? String) ?? "codex", $0)] } ?? []
        var rows: [QuotaWindow] = []
        var plan: String?
        for (key, bucket) in entries {
            plan = plan ?? bucket["planType"] as? String
            let label = (bucket["limitName"] as? String) ?? (key == "codex" ? "" : key)
            for kind in ["primary", "secondary"] {
                guard let window = bucket[kind] as? [String: Any] else { continue }
                let duration = (window["windowDurationMins"] as? Int).map(durationLabel(minutes:)) ?? kind.capitalized
                rows.append(QuotaWindow(id: "\(key)-\(kind)", title: label.isEmpty ? duration : "\(label) · \(duration)",
                                        remaining: remainingPercent(used: window["usedPercent"]),
                                        reset: unixDate(window["resetsAt"])))
            }
        }
        return QuotaResult(windows: rows, plan: plan)
    }

    static func durationLabel(minutes: Int) -> String {
        if minutes == 10080 { return "Weekly" }
        if minutes % 1440 == 0 { return "\(minutes / 1440)-day" }
        if minutes % 60 == 0 { return "\(minutes / 60)-hour" }
        return "\(minutes)-minute"
    }

    static func unixDate(_ value: Any?) -> Date? {
        guard let seconds = (value as? NSNumber)?.doubleValue, seconds.isFinite, seconds > 0 else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }
}

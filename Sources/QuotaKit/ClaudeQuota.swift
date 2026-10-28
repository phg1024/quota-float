import Foundation

/// Reads Claude plan usage limits through the signed-in Claude Code CLI. A print-mode process is sent only the
/// `get_usage` control request (the data behind `/usage`); no user message is sent, so no model turn starts.
/// Claude Code marks this request experimental, so its shape may change.
public enum ClaudeQuota {
    static let requestID = "quota-float-usage"
    static let arguments = ["-p", "--input-format", "stream-json", "--output-format", "stream-json", "--verbose",
                            "--no-session-persistence", "--strict-mcp-config", "--settings", #"{"disableAllHooks":true}"#]

    public static func fetch() throws -> QuotaResult {
        let home = FileManager.default.homeDirectoryForCurrentUser
        guard let executable = findExecutable([ProcessInfo.processInfo.environment["CLAUDE_BINARY"],
            home.appendingPathComponent(".local/bin/claude").path,
            "/opt/homebrew/bin/claude", "/usr/local/bin/claude"]) else {
            throw QuotaError("Claude Code CLI not found. Install Claude Code, then reopen this app.")
        }
        let request: [String: Any] = ["type": "control_request", "request_id": requestID,
                                      "request": ["subtype": "get_usage", "skip_behaviors": true]]
        return try exchangeJSONLines(executable: executable, arguments: arguments,
                                     environment: environment(from: ProcessInfo.processInfo.environment),
                                     first: request, service: "Claude",
                                     unreachable: "Couldn’t reach Claude. Check your connection and ‘claude auth login’, then refresh.") { message, _ in
            guard message["type"] as? String == "control_response", let response = message["response"] as? [String: Any],
                  response["request_id"] as? String == requestID else { return nil }
            if response["subtype"] as? String == "error" {
                throw QuotaError((response["error"] as? String) ?? "Unable to read Claude usage.")
            }
            let usage = (response["response"] as? [String: Any]) ?? [:]
            guard usage["rate_limits_available"] as? Bool == true else {
                throw QuotaError("Claude plan limits unavailable. Sign the Claude CLI in with your Claude plan using ‘claude auth login’.")
            }
            let parsed = parse(usage)
            guard !parsed.windows.isEmpty else { throw QuotaError("Claude hasn’t reported plan usage yet. Refresh later.") }
            return parsed
        }
    }

    /// API keys, gateways and host-session variables (e.g. when launched from a shell inside Claude Code) hide plan
    /// limits, so they are dropped and a shell launch reads the same signed-in plan as a Finder launch.
    static func environment(from environment: [String: String]) -> [String: String] {
        environment.filter { key, _ in
            key == "CLAUDE_CODE_OAUTH_TOKEN" || !(key.hasPrefix("ANTHROPIC_") || key.hasPrefix("CLAUDE_CODE_") || key == "CLAUDECODE")
        }
    }

    /// Parses a `get_usage` response. Windows report `utilization` (percent used) and an ISO 8601 `resets_at`.
    public static func parse(_ usage: [String: Any]) -> QuotaResult {
        let plan = usage["subscription_type"] as? String
        guard let limits = usage["rate_limits"] as? [String: Any] else { return QuotaResult(windows: [], plan: plan) }
        var entries: [(key: String, title: String, window: [String: Any])] = [
            ("five_hour", "5-hour"), ("seven_day", "Weekly · all models"), ("seven_day_opus", "Weekly · Opus"),
            ("seven_day_sonnet", "Weekly · Sonnet"), ("seven_day_oauth_apps", "Weekly · OAuth apps"),
        ].compactMap { key, title in (limits[key] as? [String: Any]).map { (key, title, $0) } }
        for (index, scoped) in ((limits["model_scoped"] as? [[String: Any]]) ?? []).enumerated() {
            let title = "Weekly · \((scoped["display_name"] as? String) ?? "Model")"
            if !entries.contains(where: { $0.title == title }) { entries.append(("model-\(index)", title, scoped)) }
        }
        let rows = entries.map { entry in
            QuotaWindow(id: "claude-\(entry.key)", title: entry.title,
                        remaining: remainingPercent(used: entry.window["utilization"]), reset: isoDate(entry.window["resets_at"]))
        }
        return QuotaResult(windows: rows, plan: plan)
    }

    private static let fractionalISO: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private static let plainISO = ISO8601DateFormatter()

    static func isoDate(_ value: Any?) -> Date? {
        guard let text = value as? String else { return nil }
        return fractionalISO.date(from: text) ?? plainISO.date(from: text)
    }
}

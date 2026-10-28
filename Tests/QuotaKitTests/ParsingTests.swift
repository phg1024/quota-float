import Foundation
import Testing
@testable import QuotaKit

@Suite struct CodexParsingTests {
    @Test func prefersBucketsAndConvertsToRemaining() {
        let result = CodexQuota.parse([
            "rateLimitsByLimitId": [
                "codex": ["planType": "pro",
                          "primary": ["usedPercent": 12, "windowDurationMins": 300, "resetsAt": 1_793_169_000],
                          "secondary": ["usedPercent": NSNull(), "windowDurationMins": 10080]],
                "other": ["primary": ["usedPercent": 150]],
            ],
            "rateLimits": ["primary": ["usedPercent": 90]],
        ])
        #expect(result.plan == "pro")
        #expect(result.windows.map(\.title) == ["5-hour", "Weekly", "other · Primary"])
        #expect(result.windows.map(\.remaining) == [88, nil, 0])
        #expect(result.windows[0].reset == Date(timeIntervalSince1970: 1_793_169_000))
    }

    @Test func fallsBackToSingleBucket() {
        let result = CodexQuota.parse(["rateLimits": ["primary": ["usedPercent": -10, "windowDurationMins": 1440]]])
        #expect(result.windows.map(\.title) == ["1-day"])
        #expect(result.windows.first?.remaining == 100)
    }

    @Test func emptyAndInvalidValues() {
        #expect(CodexQuota.parse([:]).windows.isEmpty)
        let result = CodexQuota.parse(["rateLimits": ["primary": ["usedPercent": "12", "resetsAt": -5, "windowDurationMins": 45]]])
        #expect(result.windows.first?.remaining == nil)
        #expect(result.windows.first?.reset == nil)
        #expect(result.windows.first?.title == "45-minute")
    }
}

@Suite struct ClaudeParsingTests {
    @Test func parsesPlanWindowsInOrder() throws {
        let result = ClaudeQuota.parse([
            "subscription_type": "max", "rate_limits_available": true,
            "rate_limits": [
                "five_hour": ["utilization": 5, "resets_at": "2026-10-28T06:30:00.759Z"],
                "seven_day": ["utilization": NSNull(), "resets_at": NSNull()],
                "seven_day_opus": NSNull(),
                "model_scoped": [["display_name": "Fable", "utilization": 120, "resets_at": "2026-11-01T21:00:00Z"],
                                 ["display_name": "Opus", "utilization": 1, "resets_at": NSNull()]],
            ],
        ])
        #expect(result.plan == "max")
        #expect(result.windows.map(\.title) == ["5-hour", "Weekly · all models", "Weekly · Fable", "Weekly · Opus"])
        #expect(result.windows.map(\.remaining) == [95, nil, 0, 99])
        let reset = try #require(result.windows[0].reset)
        #expect(abs(reset.timeIntervalSince1970 - 1_793_169_000.759) < 0.01)
        #expect(result.windows[1].reset == nil)
        #expect(result.windows[2].reset == Date(timeIntervalSince1970: 1_793_566_800))
    }

    @Test func skipsDuplicateModelTitles() {
        let result = ClaudeQuota.parse(["rate_limits": [
            "seven_day_opus": ["utilization": 10, "resets_at": NSNull()],
            "model_scoped": [["display_name": "Opus", "utilization": 20, "resets_at": NSNull()]],
        ]])
        #expect(result.windows.map(\.remaining) == [90])
    }

    @Test func missingLimits() {
        #expect(ClaudeQuota.parse(["rate_limits_available": false, "rate_limits": NSNull()]).windows.isEmpty)
    }

    @Test func environmentDropsAPIKeysAndHostVariables() {
        let environment = ClaudeQuota.environment(from: [
            "HOME": "/Users/me", "PATH": "/usr/bin", "ANTHROPIC_API_KEY": "x", "ANTHROPIC_BASE_URL": "x",
            "CLAUDECODE": "1", "CLAUDE_CODE_SIMPLE": "1", "CLAUDE_CODE_OAUTH_TOKEN": "keep", "CLAUDE_CONFIG_DIR": "/c",
        ])
        #expect(Set(environment.keys) == ["HOME", "PATH", "CLAUDE_CODE_OAUTH_TOKEN", "CLAUDE_CONFIG_DIR"])
    }
}

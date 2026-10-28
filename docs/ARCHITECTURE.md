# Architecture

Quota Float is a Swift package with no third-party dependencies.

```text
Package.swift
Sources/QuotaKit/        Data layer: no UI, unit-tested
  Quota.swift            QuotaWindow, QuotaResult, QuotaError, percent helpers
  JSONLineSession.swift  Runs a CLI that speaks newline-delimited JSON over stdio
  CodexQuota.swift       Codex CLI source and parser
  ClaudeQuota.swift      Claude Code CLI source and parser
Sources/QuotaFloat/      AppKit/SwiftUI app
  main.swift             Entry point, --check and --version
  QuotaModel.swift       QuotaService list, per-service state and refresh scheduling
  QuotaView.swift        SwiftUI panel content
  QuotaPanel.swift       Floating panel and title dragging
  StatusGauge.swift      Menu-bar gauge image and text summaries
  AppDelegate.swift      Panel, status item, menu and wake handling
Tests/QuotaKitTests/     Swift Testing tests for parsers and the subprocess exchange
Support/                 Info.plist template (version substituted at build time) and icon
scripts/                 build.sh, test.sh, make-icon.swift
```

## Data flow

1. `QuotaModel` refreshes every service on launch, on wake and on demand. A 60-second timer refreshes each service when its `refreshInterval` is due: 60 s for Codex, 300 s for Claude, because each Claude check starts a full Claude Code process. Concurrent refreshes of one service are suppressed.
2. Each fetch runs on a utility queue. Success replaces that service's rows, plan and timestamp. Failure only records the error, so the panel and gauge show the old values as stale.
3. `exchangeJSONLines` starts the CLI in the temporary directory with stderr discarded and sends one JSON line. It reads stdout through a buffered, non-blocking `LineReader`, skips lines that aren't JSON objects, and passes each message to the caller until it gets a result. The exchange has a hard deadline (25 s). On return the process is sent SIGTERM, then SIGKILL two seconds later if it is still running. The app ignores SIGPIPE so a CLI that exits early can't crash it.

### Codex

`codex app-server`: request `initialize` (id 1), notify `initialized`, request `account/rateLimits/read` (id 2). `CodexQuota.parse` prefers a nonempty `rateLimitsByLimitId` (sorted by key) and falls back to `rateLimits`. It reads each bucket's `primary` and `secondary` window: `usedPercent`, `windowDurationMins`, and `resetsAt` (Unix seconds).

### Claude

`claude -p --input-format stream-json --output-format stream-json --verbose --no-session-persistence --strict-mcp-config --settings {"disableAllHooks":true}`, then one `control_request` with `{"subtype":"get_usage","skip_behaviors":true}`. No user message is sent, so no model turn starts. Closing stdin ends the process.

The response has `subscription_type`, `rate_limits_available`, and `rate_limits` with optional `five_hour`, `seven_day`, `seven_day_opus`, `seven_day_sonnet` and `seven_day_oauth_apps`. Each is `{utilization: 0–100 | null, resets_at: ISO 8601 | null}` or null. There is also a `model_scoped` array of `{display_name, utilization, resets_at}`. Claude Code labels `get_usage` experimental; re-check the schema against the installed CLI if it stops working.

`ClaudeQuota.environment(from:)` removes `ANTHROPIC_*`, `CLAUDE_CODE_*` (except `CLAUDE_CODE_OAUTH_TOKEN`) and `CLAUDECODE`. API keys, gateways and host-session variables (for example, in a shell opened inside Claude Code) would otherwise make the CLI report that plan limits are unavailable.

## UI notes

- The panel is a borderless, non-activating `NSPanel` at floating level that joins all Spaces. It is resized to fit its SwiftUI content while keeping its top edge fixed.
- Title dragging is handled in three overlapping places: `QuotaPanel.sendEvent` (top 48 pt, left of the buttons), the hosting view's first-mouse and background dragging, and `WindowDragHandle`. They were added together to fix a panel that ignored the mouse. Before simplifying them, re-test dragging, first click on an inactive panel, and the refresh and hide buttons.
- The menu-bar gauge is an `NSImage` drawn by a closure each time it is displayed, so `labelColor` follows a light or dark menu bar. Each service shows its first two windows; the number is the lower of those two remaining percentages.

## Testing

`scripts/test.sh` runs `swift test`. With only the Command Line Tools installed, it adds the Swift Testing framework paths and disables cross-import overlays, because some Command Line Tools versions ship without the `_Testing_Foundation` module. The subprocess tests use `/bin/sh` scripts in place of the CLIs, including one that ignores SIGTERM, to check that the timeout and kill path is bounded.

`QuotaFloat --check` exercises the live CLIs without the UI.

## Ideas

- Restore a saved position that is now off-screen (display disconnected) and add a "Reset position" menu item.
- Show relative reset countdowns and the age of stale data.
- Settings for per-service visibility and refresh intervals; an optional launch-at-login toggle.

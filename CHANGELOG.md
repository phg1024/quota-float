# Changelog

## 1.0.0 — 2026-10-27

First public release.

- Floating panel showing remaining Codex (ChatGPT plan) quota and Claude plan usage limits, with reset times.
- Compact menu-bar gauge for both services, with a text summary in the tooltip and menu.
- Reads quota through the signed-in Codex and Claude Code CLIs; no API keys and no token handling.
- Keeps the last good values with a stale-data notice when a refresh fails.
- Universal (Apple silicon and Intel) app for macOS 13 or later.

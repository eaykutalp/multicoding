# Changelog

## 0.8.6

- Fixes Codex remote session resume when the project setting to skip permission prompts is enabled. Remote resume no longer passes an unsupported CLI permission override.

## 0.8.5

- Generates unique session numbers per project, repairs duplicate app-generated names on launch and covers standard, recent and worktree session creation.
- Adds a project setting to skip permission prompts for Claude Code, Codex and Antigravity. Codex uses `never` approvals with `danger-full-access`; the setting is off by default.

## 0.8.4

- Starts the local Codex TUI client from the home directory while keeping the remote thread attached to its project workspace. This avoids local config refreshes probing macOS-protected Desktop/Documents project paths.

## 0.8.3

- Adds the latest DMG/ZIP release links to the top of the README.
- Selecting Play on a session now selects and reveals its terminal.
- Shows Codex root and subagent permission requests under their session with per-request Allow/Deny actions.
- Updates Codex resume commands to use the MultiCoding token environment variable (fixes the stale 0.8.0 command when the app is updated).

## 0.8.2

- Consolidates previous-install session, preference and worktree-command migration in one compatibility file.
- Uses MultiCoding names throughout source, tests, resources and user-facing docs.

## 0.8.1

- Renamed the Swift package, app target, source and test folders to MultiCoding.
- Migrates existing projects and sessions into the MultiCoding support folder on first launch.
- Updated Antigravity and Codex integration labels and internal identifiers.

## 0.8.0

- Initial MultiCoding release with Claude Code, Codex and Antigravity sessions.
- Project sidebar, session resume, Git worktrees, change review, file preview and local browser panel.

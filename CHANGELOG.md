# Changelog

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

# Privacy

MultiCoding has no telemetry. Its integrations use these network paths:

- **Usage limits.** To show your plan limits, MultiCoding reads Claude Code's login from the macOS Keychain (the `Claude Code-credentials` item, via `/usr/bin/security`) and sends it to `https://api.anthropic.com/api/oauth/usage`, the same endpoint Claude Code's `/usage` command uses. The token is never written to disk or logged. This endpoint is undocumented and may change or stop working at any time.
- **Pull request status.** If `gh` is installed, MultiCoding runs `gh pr view` for each worktree session's branch about once a minute and when you switch back to the app. Sending failing checks to a session runs `gh run view --log-failed` for those checks. gh uses its own login; MultiCoding never reads or stores your GitHub token.
- **Codex.** MultiCoding communicates with its per-session Codex app-servers over authenticated loopback WebSockets. Codex itself connects to the model provider, tools, and services configured in your Codex settings. Usage is requested through `account/rateLimits/read`; accounts without supported plan limits display an unavailable message. MultiCoding starts its app-servers with analytics disabled.

Local files MultiCoding touches:

- `~/Library/Application Support/MultiCoding/workspace.json`: your projects and sessions (plus a `.bak` copy). On upgrade, MultiCoding copies the previous app's workspace into this folder and leaves the original intact.
- `~/.claude/projects`: read to list recent conversations, to check whether a session's conversation exists, and to show a running session's subagents and their transcripts.
- Worktree sessions run `git` in your repository, and creating a pull request runs `git push` through your login shell. Nothing else is pushed or committed unless you confirm it.
- Elements picked in the browser are saved under your temporary folder (`MultiCoding-picks`) so Claude can read them.
- Settings are stored in the standard macOS preferences.

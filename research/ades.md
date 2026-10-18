# Agentic Development Environments

A comparison of agentic development environments (ADEs): apps for running several coding agents in parallel, each in its own worktree, and reviewing what they did. It covers Paseo, cmux, Orca and Cursor in depth, and six others briefly, as of 2026-10-18.

Repository stats, licenses and releases were checked on 2026-10-18 with `gh api`. Features come from each project's README or docs; none of the apps were run for this comparison. Earlier notes on Paseo, cmux and Orca are in [Agentic Tools](agentic-tools.md).

## Summary

Keep Orca, which is already the [Toolbox](../docs/toolbox.md) choice. It is the only one of the four that is MIT-licensed, runs on macOS and Linux, uses the real agent CLIs under my own subscriptions, and covers the whole loop: worktrees, terminals, inline diff comments sent back to the agent, a scripting CLI, SSH worktrees and a phone app. Its one mark against the toolbox principles is anonymous telemetry, which is on by default and can be turned off.

- **Paseo:** the best fit for scripting. It is a headless daemon with a CLI, TypeScript SDK, WebSocket API and MCP server, with no telemetry. Watch it as the backend for [marche](../docs/marche.md), or as the replacement if Orca's scripting falls short.
- **cmux:** the best terminal of the four, built on libghostty and reading my Ghostty config. But it is macOS only, has no worktree management or diff review, and its server parts are BUSL. Worth it only as a Mac terminal.
- **Cursor:** skip. It is proprietary and bills its own models. Its Agents Window manages Cursor's agents, not Claude Code under my subscription, and it is the kind of monolith the toolbox avoids.

## What matters

These come from the [Toolbox](../docs/toolbox.md) principles and the earlier research:

- **Real agent CLIs:** runs Claude Code itself, under my subscription, not a re-implementation or a separately billed model.
- **Worktree per agent:** with an easy way to compare and merge.
- **Review loop:** inline comments on the diff that go back to the agent (see [Review Tools](review-tools.md)).
- **Scriptable:** a CLI or API so marche and agents can drive it.
- **Platforms:** macOS for work and NixOS for home.
- **Open and transparent:** an open-source license, no forced login, and telemetry off or opt-out.
- **Remote and mobile:** check on agents from a phone, and run agents on another machine.

## The four

| | [Orca](https://github.com/stablyai/orca) | [Paseo](https://github.com/getpaseo/paseo) | [cmux](https://github.com/manaflow-ai/cmux) | [Cursor](https://cursor.com) |
| --- | --- | --- | --- | --- |
| What it is | Desktop app for a fleet of CLI agents | Daemon with desktop, mobile, web and CLI clients | Native macOS terminal built on libghostty | VS Code fork with an Agents Window |
| Activity | 95K stars, v1.4.229 (2026-10-17) | 21K stars, v0.11.4 (2026-10-15) | 28K stars, v0.65.2 (2026-10-16) | Cursor 3.0 (2026-04-02), 3.11 (2026-07-10) |
| License | MIT | Apache-2.0, except bundled third-party parts | App GPL-3.0; server parts BUSL-1.1 | Proprietary |
| Agents | Any CLI agent: Claude Code, Codex, Copilot, OpenCode, Pi, Amp, Goose and more, on your own subscriptions | Claude Code, Codex, Copilot, OpenCode, Pi and others, with your own credentials | Anything that runs in a terminal | Cursor's own agents and models, billed by Cursor; other CLIs only in its terminal |
| Worktrees | One per agent; fan a prompt out to several agents and merge the best | One per agent, also from the CLI (`--worktree`) | Not managed | `/worktree`, plus cloud and SSH agents |
| Diff review | Inline comments, then **Send to agent** as one line-anchored prompt | Review diffs and open PRs; no inline comments mentioned | None | Review diffs in the Agents Window |
| Terminal | Splits with WebGL rendering and persistent scrollback | Split-pane terminals | The product: Ghostty rendering, vertical tabs, agent notifications | VS Code terminal |
| Scripting | `orca` CLI (`worktree create`, `snapshot`, `click`, `fill`) | `paseo` CLI (`run`, `ls`, `attach`, `send`), TypeScript SDK, WebSocket API, MCP server | CLI and Unix socket: workspaces, panes, send input, read screen, drive the browser | `cursor-agent` CLI for Cursor's agent |
| Browser | Embedded Chromium with Design Mode, which sends a clicked element to the agent | Built-in browser | Scriptable browser pane | Built in |
| Remote and mobile | SSH worktrees; iOS app and Android APK | Remote daemon over Tailscale, a VPN, or an optional end-to-end encrypted relay (self-hostable); iOS and Android apps | `cmux ssh`; iOS app in beta | Cloud and SSH agents; web and mobile |
| Platforms | macOS, Linux, Windows | Linux, Windows, macOS (server via npm or Docker) | macOS only | macOS, Linux, Windows |
| Telemetry | Anonymous usage data, opt-out | None, no forced login | Not stated | Yes (proprietary service) |
| Paid parts | None listed | None listed | Founder's Edition (cmux AI, cloud VMs, iOS app) | Subscription |

### Orca

The broadest open-source match. Everything the factory currently hands off goes through it, and its Annotate AI Diff feature already closes the review loop. The gaps are telemetry (turn it off) and a scripting CLI that is younger than Paseo's API. It's Electron, so it is heavier than cmux.

### Paseo

Built as a daemon first, so everything the apps do is also available to scripts: start an agent, list agents, attach, send input, and wait for completion through the SDK. That shape suits marche, which needs to dispatch agents and wait on them, and it runs headless on a server or a Temporal worker. The README doesn't mention inline diff comments, so for review it would pair with a tool from [Review Tools](review-tools.md).

### cmux

A terminal, not a full ADE. Its notification rings, sidebar of branches and PRs, socket API and browser pane are excellent for watching many agents, and it reads the existing Ghostty config. But it doesn't manage worktrees or review diffs, it is macOS only, so it doesn't help at home on NixOS, and self-hosting its server parts needs a commercial license.

### Cursor

A capable product, and Cursor 3's Agents Window runs agents locally, in worktrees, in the cloud and over SSH. But it is proprietary, ties agents to Cursor's billing and models, and replaces the editor and terminal wholesale. That breaks three toolbox principles: open standards, easy to switch, and no monoliths.

## Others

| Tool | What it is | License, activity | Verdict |
| --- | --- | --- | --- |
| [Claude Code desktop](https://code.claude.com/docs/en/desktop) | Anthropic's app: sessions in worktrees, a diff view with line comments, a "Review code" button, scheduled routines | Proprietary | **Watch:** first-party, but only for Claude, and not scriptable from outside |
| [Superset](https://github.com/superset-sh/superset) | Electron ADE for real CLI agents on your subscriptions; sends selected diff lines as feedback; CLI, SDK and MCP server | Elastic License 2.0, 15K stars, desktop v1.38.0 | **Skip:** not open source; Linux is experimental; mobile needs Pro |
| [Emdash](https://github.com/generalaction/emdash) | Electron ADE (YC W26); detects installed agent CLIs; sends issues from Linear, GitHub, Jira and others to agents; SSH remotes | Apache-2.0, 6K stars, v1.2.8 | **Watch:** good issue-tracker intake; no inline comments back to the agent; telemetry optional |
| [Nimbalyst](https://github.com/nimbalyst/nimbalyst) | Visual workspace for Claude Code, Codex and OpenCode; formerly Crystal | MIT, 1.9K stars, v0.81.7 | **Skip:** overlaps with Orca |
| [Zed](https://github.com/zed-industries/zed) | Rust editor that runs external agents over the Agent Client Protocol | GPL/AGPL mix, 92K stars, v1.24.2 | **Watch:** an editor, not an ADE; useful as an ACP host |
| [Warp](https://github.com/warpdotdev/warp) | Terminal marketed as an agentic development environment | AGPL-3.0, 65K stars | **Skip:** its own agent and account; an all-in-one |

## Recommendation

1. **Keep Orca** as the ADE, and turn its telemetry off.
2. **Trial Paseo's daemon and SDK** as the way marche dispatches and waits on agents, since that is where Orca's scripting is thinnest. Running both is reasonable: Paseo headless underneath, Orca as the visual surface.
3. **Use cmux only as a Mac terminal** if Ghostty-style rendering with agent notifications is wanted; it doesn't replace Orca.
4. **Skip Cursor, Superset and Warp** on license and lock-in grounds.

## Open questions

- Does Orca's CLI cover what marche needs: start an agent in a worktree, send it a prompt, and know when it's done? If not, Paseo's SDK does.
- Orca or Paseo on NixOS: are they packaged, or is it an AppImage?
- Should the [Terminal Orchestration](terminal-orchestration.md) tool become an adapter over Orca and Paseo rather than its own thing?

## Sources

- [Orca](https://github.com/stablyai/orca) and its [Annotate AI Diff docs](https://www.onorca.dev/docs/review/annotate-ai-diff)
- [Paseo](https://github.com/getpaseo/paseo)
- [cmux](https://github.com/manaflow-ai/cmux)
- [Cursor 3.0 changelog](https://cursor.com/changelog/3-0)
- [Cursor CLI changelog](https://cursor.com/docs/cli/changelog.md)
- [What is Cursor 3?](https://www.datacamp.com/blog/cursor-3)
- [Superset](https://github.com/superset-sh/superset)
- [Emdash](https://github.com/generalaction/emdash)
- [Nimbalyst](https://github.com/nimbalyst/nimbalyst)
- [Zed](https://github.com/zed-industries/zed)
- [Warp](https://github.com/warpdotdev/warp)

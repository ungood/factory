# Terminal Orchestration

How an agent, or [marche](../docs/marche.md), should open and drive terminals for me, as of 2026-10-18. The goal is a scriptable layer that works with more than one terminal. This is an open decision; the questions at the end need answers before anything is built.

GitHub issue and PR states were checked on 2026-10-18 with `gh api`. Terminal support for escape sequences other than in Windows Terminal and WezTerm comes from secondhand sources.

## Summary

There is no standard for controlling a terminal from outside: opening tabs, splitting panes or reading the screen. Each terminal has its own API. Standards exist around that gap, though, and together they give most of the portability:

- **Interface shape:** the [Agent Client Protocol](https://agentclientprotocol.com/protocol/v1/terminals) terminal methods are the closest standard for "an agent asks the host for a terminal." Use them as the shape of our interface.
- **Observing commands:** OSC 133 semantic prompts report command start, end and exit code, in-band, across many terminals.
- **Portability:** tmux is the de facto standard. It works in every terminal, over SSH and detached.

Native tabs and panes driven by tmux (control mode) are mature only in iTerm2. Ghostty is building it but hasn't shipped it.

## What the agent needs

- Open a tab, pane or window with a working directory, command and title, and get an ID back.
- Send text or keys to an existing terminal.
- Read its screen or scrollback.
- Detect when a command exits, and with what code.
- Close terminals, and lay them out one per worktree or one per agent.
- Ideally: work detached, over SSH, and on both macOS (work) and NixOS (home).

## Standards by layer

### Interface: Agent Client Protocol terminal methods

ACP, from Zed, defines terminals as something the client (host) owns and the agent requests. Editors implement it, terminal emulators don't, so this is a shape to copy, not something terminals speak.

| Method | What it does |
| --- | --- |
| `terminal/create` | Command, args, env, absolute working directory, output byte limit; returns an ID at once while the command runs |
| `terminal/output` | Output so far, a `truncated` flag, and `exitStatus` (code and signal) once exited |
| `terminal/wait_for_exit` | Blocks until the command exits |
| `terminal/kill` | Stops the command, keeps the terminal |
| `terminal/release` | Required cleanup |

Agents must check the client's `terminal` capability before calling any of these. ACP has no layout, focus, title or send-keys, so our interface would extend it.

### In-band: escape sequences

These are real cross-terminal standards. They let a program tell its terminal what is happening, but they can't open panes or be read from outside.

- **OSC 133 (semantic prompts):** marks prompt start, command start, output start, and command end with an exit code. Stable in [Windows Terminal](https://learn.microsoft.com/en-us/windows/terminal/tutorials/shell-integration) since 1.21 and documented in [WezTerm](https://wezfurlong.org/wezterm/shell-integration.html). iTerm2, kitty, Ghostty and VS Code reportedly support it too. This is the portable way to detect "command finished, exit 0."
- **OSC 7:** reports the current directory.
- **OSC 0 and 2:** set the title.
- **OSC 9 and 777:** desktop notifications, useful for "waiting for your approval."

### Portability: tmux

tmux covers every need above: sessions, windows and panes with a directory and command, `send-keys`, `capture-pane`, `wait-for`, hooks and `pipe-pane`. It runs inside any terminal, survives detach, and works on remote machines and Temporal workers. Claude Code's agent teams already use tmux (and iTerm2) as split-pane backends.

Its [control mode](https://github.com/tmux/tmux/wiki/Control-Mode) (`tmux -CC`) is a text protocol, designed by iTerm2's author, that lets a GUI terminal draw tmux windows and panes as native tabs and splits. That gives native scrollback, search and copy while tmux keeps the session alive.

### Launch only

- **Linux:** [xdg-terminal-exec](https://man.archlinux.org/man/extra/xdg-terminal-exec/xdg-terminal-exec.1.en) opens the default terminal with a command. Still a freedesktop proposal.
- **macOS:** `open -a` or AppleScript.
- **Windows:** `wt`.

These open a window and give no control afterward.

## Native tabs and panes

Two ways to get native UI: a terminal that renders tmux control mode, or a terminal with its own built-in multiplexer and CLI.

| Terminal | tmux control mode | Own scriptable tabs and panes | Platforms | Status |
| --- | --- | --- | --- | --- |
| [iTerm2](https://iterm2.com/documentation-tmux-integration.html) | Yes, the reference implementation | Python API, AppleScript | macOS only | Mature |
| [Ghostty](https://github.com/ghostty-org/ghostty/issues/1935) | In progress: parser fixes merged to `main` on 2026-10-13 ([#14671](https://github.com/ghostty-org/ghostty/pull/14671), [#14676](https://github.com/ghostty-org/ghostty/pull/14676)); a native-windows PR ([#14248](https://github.com/ghostty-org/ghostty/pull/14248)) closed unmerged; feature issue still open | Limited | macOS, Linux | Not in a release (latest v1.3.1) |
| [WezTerm](https://github.com/wez/wezterm) | Reportedly merged to nightly in 2025, with crash reports | Yes: `wezterm cli spawn`, `split-pane`, `send-text`, `get-text`, plus its own mux server for persistent and remote sessions | macOS, Linux, Windows | Last stable release 2024-02-03; nightlies only since |
| [kitty](https://sw.kovidgoyal.net/kitty/remote-control/) | No | Yes: `kitty @ launch`, `send-text`, `get-text`, layouts; remote control must be enabled | macOS, Linux | Active |
| [cmux](https://github.com/manaflow-ai/cmux) | Beta bridge to remote tmux over control mode (tmux 3.2+) | Built for AI agents: vertical tabs, notifications, programmable | macOS only | Ghostty-based, 28K stars, license unclear |
| Alacritty, Warp, Terminal.app, Windows Terminal | No | No or minimal | Various | Not candidates |

**Reading the table:**

- **For tmux-backed native tabs today:** iTerm2 is the only mature choice, and it is macOS only.
- **Ghostty (my current terminal):** worth watching, since control-mode work is landing now, but not usable yet.
- **For native tabs on both macOS and NixOS without tmux:** WezTerm or kitty. WezTerm's mux server even replaces tmux for persistent and remote sessions, but its release cadence is a risk.

## Recommendation

1. **Define our own small interface shaped like ACP's terminal methods:** create, output, wait for exit, kill, release, plus `send`, `focus`, `title` and `layout`.
2. **Write adapters behind it:**
   - **tmux** as the default, since it works locally, remotely and on workers, and terminals that render control mode give native tabs for free.
   - **One GUI adapter** for visible native panes: iTerm2 at work, or WezTerm or kitty on both machines.
   - **Orca**, since agent work is already handed off through Orca terminals and worktrees.
3. **Detect exits through OSC 133** where the terminal supports it. Otherwise the adapter wraps the command so it writes its exit code somewhere readable.
4. **Expose it two ways:** a CLI for me and marche, and an MCP server so Claude Code can call it.
5. **Make it a marche step:** a `terminal` task that opens a pane in the run's worktree at a human gate.

## Open questions

- **Visible windows or detached sessions by default?** Visible points to a GUI adapter first; detached points to tmux first.
- **Stay on Ghostty, or switch?** Staying means tmux without native tabs until Ghostty ships control mode. Switching means iTerm2 (macOS only) or WezTerm/kitty (both machines).
- **Remote machines and Temporal workers:** does the tool need to open terminals there? If so, tmux is required.
- **Separate CLI or part of marche?** A separate small tool fits the Unix principle in [Toolbox](../docs/toolbox.md). It would need a name that fits the kitchen naming.
- **Does Orca already cover enough of this** to make the tool unnecessary?

## Sources

- [Agent Client Protocol: terminals](https://agentclientprotocol.com/protocol/v1/terminals)
- [tmux control mode](https://github.com/tmux/tmux/wiki/Control-Mode)
- [Windows Terminal shell integration](https://learn.microsoft.com/en-us/windows/terminal/tutorials/shell-integration)
- [WezTerm shell integration](https://wezfurlong.org/wezterm/shell-integration.html)
- [Ghostty issue #1935: tmux control mode](https://github.com/ghostty-org/ghostty/issues/1935)
- [cmux](https://github.com/manaflow-ai/cmux)
- [xdg-terminal-exec](https://man.archlinux.org/man/extra/xdg-terminal-exec/xdg-terminal-exec.1.en)
- [iTerm2 tmux integration (third-party guide)](https://tmux.app/doc/iterm2/)
- [Terminal emulator comparison 2026](https://blog.luminoid.dev/Terminal-Emulator-Comparison-2026/)

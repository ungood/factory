# Review Tools

Terminal tools for seeing what an agent changed and commenting on it inline, as of 2026-10-18. The comments should go back to the agent as structured feedback, and the same tool should work as a human gate in [marche](../docs/marche.md).

Repository stats and releases were checked on 2026-10-18 with `gh api`. Feature lists come from each project's README.

## Summary

Start with **Orca**, which is already in the toolbox. Its diff view takes inline comments on agent changes, and "Send to agent" pipes them as one line-anchored prompt straight into the agent's terminal. That is the whole loop with no copying, and it's a GUI.

For a terminal alternative, two TUIs were built for this: **tuicr** and **revdiff**. Each shows the agent's diff with a file tree and syntax highlighting, takes line, range and file comments, and hands them back with file and line anchors. General diff viewers such as lazygit, diffnav and delta are good for reading changes, but none of them take comments.

- **tuicr:** Rust and MIT, with a GitHub-style continuous diff, side-by-side view, typed comments, persistent review sessions, and posting the review to a GitHub PR. Getting comments back to the agent is the weak spot: you copy them (`y`), or the agent reads them with `tuicr review comments` (see [How tuicr comments reach the agent](#how-tuicr-comments-reach-the-agent)).
- **revdiff:** Go and MIT, with a ready-made Claude Code plugin that runs the annotate, fix, re-review loop and returns annotations to the agent when you quit. Its exit code when annotations exist suits a marche gate. It can also review whole files and documents.

## What I need

- See every file the agent touched, with a tree and syntax-highlighted diffs.
- Review uncommitted work, a commit range, or a branch against `main`, in git and ideally jj.
- Comment on a line, a range or a whole file.
- Send comments back to the agent in a format it can act on, then review again after it fixes them.
- Mark files reviewed and resume a review later.
- Launch from an agent or marche into a terminal pane (see [Terminal Orchestration](terminal-orchestration.md)).

## Built for reviewing agent changes

| Tool | Language, license | Activity | Verdict |
| --- | --- | --- | --- |
| [tuicr](https://github.com/agavra/tuicr) | Rust, MIT | 3.4K stars, v0.27.0 (2026-09-23) | **Trial:** best fit with the Rust preference |
| [revdiff](https://github.com/umputun/revdiff) | Go, MIT | 928 stars, v1.13.0 (2026-09-05) | **Trial:** best agent loop |
| [agentdiff](https://github.com/RafayK-code/agentdiff) | Python, no license | 1 star, no release | **Skip:** reviews only `HEAD~1..HEAD`, so you must commit first |

### tuicr and revdiff compared

| Feature | tuicr | revdiff |
| --- | --- | --- |
| What it reviews | Uncommitted (`-w`), commit ranges, an interactive commit picker, and remote PRs (GitHub, GitLab, Gitea, Bitbucket, Azure DevOps, Gerrit) | Uncommitted, staged, ref ranges, whole files (`--all-files`), single files, two arbitrary files, piped diffs (`gh pr diff`) |
| Version control | git, jj, Mercurial | git, jj, Mercurial |
| Layout | File sidebar and one continuous diff of all files, unified or side-by-side | File tree and one file at a time, unified only, with word diff, blame and wrap |
| Comments | Line, range, file and review-level, with configurable types (for example issue, suggestion, note, praise) | Line and file, multi-line through `$EDITOR`, plus questions (`??`) that the agent answers as a document |
| Output | Clipboard, `--stdout`, or `:submit` as a real PR review with inline comments | Markdown records on stdout when you quit, export without quitting, exit code 10 when annotations exist (`--exit-code-on-annotations`) |
| Agent integration | A skill that opens it in a cmux, tmux, Zellij or Herdr split; a `tuicr review` CLI and a Rust `ReviewStore` API for adding and reading comments | Plugins for Claude Code, Codex, OpenCode and Pi; a built-in loop that reopens until no annotations remain; a plan-review plugin on `ExitPlanMode` |
| Opening in a terminal | Split panes in cmux, tmux, Zellij, Herdr | tmux popup or persistent window, Zellij float, kitty overlay, WezTerm split, cmux, Ghostty, iTerm2, Emacs vterm |
| Reviewed state | Per file or per hunk, persisted across sessions; saved sessions can be resumed | Per file, kept on reload only if the file's diff is unchanged; review history saved on quit |
| Config | TOML, themes, `.tuicrignore` | INI, themes, remappable keys |

**Where each is stronger:**

- **tuicr:** reads like a GitHub PR. Its side-by-side view, hunk-level reviewed marks, saved sessions, and posting straight to GitHub make it the better tool for longer reviews and for carrying a review from local to the PR.
- **revdiff:** is built around the agent loop. Its plugin handles the fix and re-review cycle, its exit code makes it a natural workflow gate, and it can review plans and documents too. It is in Go, which the [Toolbox](../docs/toolbox.md) avoids for our own code, though using a Go tool is fine.

### How tuicr comments reach the agent

tuicr doesn't push anything to the agent. There are three ways to get comments back, from most to least manual:

1. **Copy and paste:** press `y` (or `:clip`) in tuicr. It copies numbered markdown with file and line anchors, which you paste into the agent's chat.
2. **Stdout:** run `tuicr -w --stdout > review.md` (or pipe it), then point the agent at the file.
3. **The agent pulls (skill):** install the skill from `skills/tuicr/SKILL.md`. The agent then runs the review loop itself:
    1. It launches tuicr in a split pane with a wrapper script, chosen by environment: `tuicr-wrapper.sh` under tmux, or the cmux, Zellij and Herdr variants. There is no Ghostty wrapper, so outside those you start tuicr yourself.
    2. It finds the session with `tuicr review list --repo .`.
    3. It waits for you. There is no notification, so it polls about every 30 seconds, or reads when you say you're done.
    4. It reads your comments as JSON with `tuicr review comments --repo . --session <slug>`. It treats `issue` as blocking, answers `note`, and ignores `praise`.
    5. It treats the review as complete when every file is marked reviewed and there are no comments.

If none of the tmux, cmux, Zellij or Herdr environments are present, option 3 falls back to "start tuicr yourself and tell the agent when you're done." That is probably where the loop felt unclear in practice.

## GUI review tools

| Tool | What it is | How comments reach the agent | License, activity | Verdict |
| --- | --- | --- | --- | --- |
| [Orca](https://www.onorca.dev/docs/review/annotate-ai-diff) | Desktop app for running agents in worktrees; already in the [Toolbox](../docs/toolbox.md) | Comment on any diff line (`c` or the gutter `+`), then **Send to agent**. Orca composes one prompt with every comment, line-anchored, and pipes it into the agent terminal that made the diff. Comments stay pinned across revisions, and unresolved ones go in the next batch | MIT, 95K stars, pushed 2026-10-18 | **Adopt:** the full loop in the tool already in use |
| [Claude Code desktop](https://code.claude.com/docs/en/desktop) | Anthropic's app; its diff view sits beside the session | Click a line number to comment, then submit all comments at once (Cmd+Enter). A "Review code" button has Claude comment on its own changes | Proprietary | **Fallback:** only for sessions run in the desktop app |
| [Plannotator](https://github.com/backnotprop/plannotator) | Local browser UI for reviewing agent plans and diffs | `/plannotator-review` opens uncommitted changes, a PR or an MR. "Send feedback" returns comments to the agent session, and approve sends "LGTM." Supports Claude Code, Codex, OpenCode, Gemini CLI and more. No telemetry, but it checks GitHub for a new release on load | Apache-2.0, 9.5K stars, pushed 2026-10-17 | **Trial:** if Orca's review falls short; it also reviews plans |
| [difit](https://github.com/yoshiko-pg/difit) | `npx difit` serves a GitHub-style diff on localhost | Copy one comment's prompt, or "Copy All Prompt," and paste it into the agent. Comments live in browser storage | MIT, 3.3K stars, pushed 2026-08-28 | **Skip:** copy and paste only |
| [Parallel Code](https://github.com/johannesjo/parallel-code), [T3 Code](https://github.com/pingdotgg/t3code), [Vibe Kanban](https://github.com/BloopAI/vibe-kanban) | Agent-in-worktree desktop apps with inline diff review | Each has inline diff comments; how they return to the agent wasn't verified | MIT / MIT / Apache-2.0 | **Skip:** they overlap with Orca |

## General diff viewers

Good for reading changes, but none of them take comments, so they complement a review tool rather than replace it.

| Tool | What it is | Language, license | Activity |
| --- | --- | --- | --- |
| [lazygit](https://github.com/jesseduffield/lazygit) | Full git TUI: staging hunks, commits, rebases | Go, MIT | 83K stars, v0.66.2 (2026-10-16) |
| [diffnav](https://github.com/dlvhdr/diffnav) | Diff pager built on delta, with a GitHub-style file tree | Go, MIT | 1.6K stars, v0.13.0 (2026-10-06) |
| [delta](https://github.com/dandavison/delta) | Syntax-highlighting pager for git diffs, grep and blame | Rust, MIT | 32.5K stars, 0.20.1 (2026-10-04) |
| [difftastic](https://github.com/Wilfred/difftastic) | Structural diff that understands syntax, so moved or reformatted code reads clearly | Rust, MIT | 26K stars, 0.71.0 (2026-09-18) |
| [tig](https://github.com/jonas/tig) | Text-mode interface for git history and diffs | C, GPL-2.0 | 13.4K stars, 2.6.1 (2026-06-13) |

## File browsing

To look around the tree beyond the diff, both of these are Rust and MIT:

- **[yazi](https://github.com/sxyazi/yazi):** a fast file manager with previews (42.9K stars, v26.9.1).
- **[broot](https://github.com/Canop/broot):** a tree navigator with git status filters (13K stars, v1.61.0).

The file trees in tuicr and revdiff already cover "what changed," so a file manager is optional.

## In marche

A review step at a human gate fits either tool:

1. marche opens the review tool in a pane on the run's worktree, through the terminal layer.
2. I comment, then quit.
3. The structured comments become the input to a fix step. revdiff's exit code 10 or a non-empty tuicr `--stdout` means "changes requested," which loops back to fix and verify. No comments means approve.

That replaces the plain approve, revise or reject signal in the reference pipeline with feedback the fix agent can act on.

## Next steps

- [ ] Try Orca's Annotate AI Diff on a real agent branch, including a second round after the agent revises.
- [ ] If a terminal tool is still wanted, install both TUIs through mise (`cargo:tuicr`, and `github:umputun/revdiff` or `go:`) and review a real agent branch with each.
- [ ] Try revdiff's Claude Code plugin loop and tuicr's skill, and compare how well the agent acts on each output format.
- [ ] Check each tool's Ghostty and tmux pane launching on macOS and NixOS.
- [ ] Pick one as the default and record it in the [Toolbox](../docs/toolbox.md).

## Sources

- [tuicr](https://github.com/agavra/tuicr)
- [revdiff](https://github.com/umputun/revdiff)
- [agentdiff](https://github.com/RafayK-code/agentdiff)
- [My new workflow for local code review with tuicr](https://www.jvt.me/posts/2026/08/25/tuicr/)
- [Review your AI's code before it hits GitHub: tuicr + gh-dash](https://corti.com/review-your-ais-code-before-it-ever-hits-github-tuicr-gh-dash-claude-code-copilot-cli/)

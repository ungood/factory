# Agentic Tools

Tools worth considering for the factory's agent layer, as of 2026-10-17. It covers four areas: orchestration, coordination, shared knowledge, and agent configuration. It builds on the earlier research in the memex vault (Software Factory Requirements, Surface Research rounds 1 and 2, Workspaces and Isolation, Knowledge and Memory, the AI Memory Systems Trade Study, and Verification), and on [Toolbox](../docs/toolbox.md). Tools those notes already covered are mentioned here only when something has changed.

Every link was checked on 2026-10-17 with `gh api` or a direct fetch. Stars, versions and dates are snapshots from that day. "Release" means the latest tagged release; when a project has none, the last push date is given instead. "mise" means the tool is in the mise registry. Otherwise it usually installs through mise's `github:`, `cargo:` or `npm:` backends.

## Summary

The biggest change since the earlier notes is that Claude Code now does much of this itself. Its workflows restart stalled agents. Sessions on the same machine can message each other over a local socket. It reads ancestor `AGENTS.md` files natively, and it emits OpenTelemetry traces. Start with those, then fill the gaps with small tools.

- **Adopt:**
  - **Claude Code native features:** workflows (with stall restarts), background sessions, cross-session messaging, `AGENTS.md` loading, and OTel. They run on the real binary under the subscription, with nothing new to install.
  - **pueue:** a Rust job queue that sits under `delegate` and Guppi.
  - **ccusage:** cost and usage reporting from Claude Code's local logs.
  - **ntfy:** push notifications from agents to my phone.
  - **fnox:** already on the list. It now also covers MCP secrets.
  - **Open Knowledge Format (OKF):** align the `kolmi` record fields with it so the store can be exported.
- **Trial:**
  - **ralphex:** the closest existing tool to the planned `delegate` loop.
  - **hcom:** a Rust messaging and wake layer for agents. It's the nearest existing thing to `moot`.
  - **AMQ:** the reference design for a file-based `moot`.
  - **ai-memory:** a Rust, git-backed, markdown-canonical shared memory. Measure it directly against building `kolmi`.
  - **Entire CLI:** session provenance stored in git refs, which feeds the learning loop.
  - **rulesync:** the renderer behind the `place` resolver.
  - **agent-perms:** the policy layer.
  - **process-compose:** a supervisor for the factory's daemons.
- **Build:** three things still have no off-the-shelf answer:
  - **`moot`:** a tree-addressed, durable, inspectable message bus.
  - **The `place` resolver:** per-kind merging across the ancestor chain.
  - **A stall watchdog:** for interactive agent sessions.
- **Avoid:** mcp_agent_mail and its Rust port. Their license rider voids rights for anyone acting for Anthropic, which includes running it with Claude.

## 1. Orchestrating agentic workflows

Claude Code's workflows (`.claude/workflows/*.js`) give plan, parallel implement, and review runs with JSON-schema outputs. They allow up to 16 agents at once and can be resumed. Stall detection is built in: an agent that stops producing output is restarted up to five times, with the timeout set by `stallMs` or `CLAUDE_ASYNC_AGENT_STALL_TIMEOUT_MS`, and the same timeout covers ordinary subagents. Background sessions (`claude --bg`, `claude agents`) run each session in its own worktree. Workflows are not an open standard, so keep the plan itself in markdown that a script can run, and treat the workflow as one way to run it.

Outside Claude Code, the useful tools are small. ralphex runs a markdown plan task by task. Each task gets a fresh `claude --print` session. After each task it runs the plan's validation commands (deterministic gates), commits, and then does a parallel review. It has an idle timeout and retries. That's the `delegate` loop already built, in Go. pueue is the queue underneath it. process-compose keeps the long-running daemons (Paseo, Guppi, an OTel collector) alive.

| Tool | What it is | License, lang | Activity | Verdict |
|---|---|---|---|---|
| [Claude Code workflows and agents](https://code.claude.com/docs/en/workflows) | Native multi-agent runs, stall restarts, background sessions, `/loop`, OTel | Proprietary | v2.1.302 | **Adopt:** real binary, built-in stall handling |
| [ralphex](https://github.com/umputun/ralphex) | Markdown plan to fresh `claude --print` per task, validation gates, review agents | MIT, Go | 1.5k stars, v1.7.0 (2026-09-07) | **Trial:** closest match to `delegate` |
| [pueue](https://github.com/Nukesor/pueue) | Daemon-backed command queue with groups, dependencies, schedules, JSON status | Apache-2.0, Rust | 6.4k stars, v4.0.4 (2026-03-02) | **Adopt:** small, Rust, stable (maintenance mode) |
| [process-compose](https://github.com/F1bonacc1/process-compose) | Process supervisor with restarts, health probes, TUI, REST API | Apache-2.0, Go | 2.9k stars, v1.122.0 (2026-08-17), mise | **Trial:** keeps factory daemons up |
| [ccusage](https://github.com/ccusage/ccusage) | Cost and usage reports from Claude Code logs | MIT, Rust core | 19k stars, v20.0.35 (2026-10-17) | **Adopt:** the only cost view that covers subscription use |
| [hcom](https://github.com/aannoo/hcom) | Launch agents through hooks; idle events, wake, spawn, fork | MIT, Rust | 577 stars, v0.7.30 (2026-10-15) | **Trial:** see section 2 |
| [GitHub Agentic Workflows](https://github.com/github/gh-aw) | Markdown workflows compiled to Actions, Claude Code engine, sandboxed "safe outputs" | MIT, Go | 5.4k stars, v0.92.0 (2026-10-15) | **Trial:** CI side only; check subscription auth |
| [ralph-orchestrator](https://github.com/mikeyobrien/ralph-orchestrator) | Ralph loop with personas and test/lint gates, about 11 backends | MIT, Rust | 3.2k stars, v2.10.1 (2026-06-23) | **Watch:** Rust but larger than ralphex, no stall handling |
| [Coven](https://github.com/OpenCoven/coven) | Rust daemon running Claude Code and Codex as PTY sessions behind a Unix socket API | MIT, Rust | 72 stars, v0.4.10 (2026-10-14) | **Watch:** right shape, very early |
| [Archon](https://github.com/coleam00/Archon) | YAML workflow graphs mixing bash and AI steps, worktrees | MIT, TypeScript | 23.7k stars, v0.12.1 (2026-10-17) | **Watch:** good ideas, but a platform built on the Agent SDK |
| [microsandbox](https://github.com/superradcompany/microsandbox) | Local microVM runtime and library | Apache-2.0, Rust | 8.7k stars, v0.7.8 (2026-10-09), mise | **Watch:** L1 isolation option if srt and nono fall short |
| [superpowers](https://github.com/obra/superpowers) | Plan, implement, review method delivered as skills | MIT | 301k stars, v7.0.0 (2026-10-10) | **Trial:** as skill content, not a runtime |
| [Gas Town](https://github.com/gastownhall/gastown) | Mayor-and-rig orchestration with a three-tier watchdog and a bisecting merge queue | MIT, Go | 18.4k stars, v1.2.1 (2026-06-06) | **Skip:** monolith; copy the watchdog and merge queue ideas |
| [Goose](https://github.com/aaif-goose/goose) | Agent with recipes and cron, now under AAIF | Apache-2.0, Rust | 55k stars, v1.55.0 (2026-10-16) | **Skip:** its Claude path is now Agent SDK only (grey zone) |
| [Temporal](https://github.com/temporalio/temporal), [Hatchet](https://github.com/hatchet-dev/hatchet) | Durable workflow engines | MIT, Go | Active | **Skip:** overkill for a laptop; Restate is BSL and Inngest is SSPL |

**Notes:**

- **Budget caps:** `--max-budget-usd` and `--max-turns` work only with `claude -p`. Proxies like LiteLLM can't see subscription traffic, so there is no cap on interactive or background sessions. ccusage plus OTel gives visibility, not enforcement.
- **Also skipped:** Paperclip, Agent Orchestrator, ruflo (formerly claude-flow), oh-my-claudecode, BMAD, Bernstein, OpenRig, Sculptor and Nimbalyst. They are monoliths, GUIs or hype-heavy. claude-squad (AGPL) is slowing, and Orca already covers it.
- **Symphony:** OpenAI's issue-tracker-as-control-plane spec is worth a read for its stall-restart model, but the reference implementation is Codex-only.

## 2. Agent coordination and communication

The protocols moved. MCP 2026-07-28 is stateless: no `initialize` handshake and no session IDs. Tasks moved out of the core into an extension, and `subscriptions/listen` replaced resource subscriptions. That makes a small MCP facade over a bus easy to write. The [Rust SDK](https://github.com/modelcontextprotocol/rust-sdk) tracks it. A2A reached 1.0 in March 2026 and has an official [Rust SDK](https://github.com/a2aproject/a2a-rs), but it is still oriented around requests and tasks, not durable mailboxes. Borrow its `Message`, `Part` and `AgentCard` shapes for an envelope and leave the transport.

Claude Code's [cross-session messaging](https://code.claude.com/docs/en/cross-session-messaging) is on by default. Each live session has a Unix socket, exported to hooks and Bash as `CLAUDE_CODE_MESSAGING_SOCKET`, plus a token. It's plain text, never leaves the machine, and is capped at 100 held messages. It reaches only live sessions and stores nothing, so it is the right way to *deliver* into a running Claude session but not a bus. [Agent teams](https://code.claude.com/docs/en/agent-teams) are still experimental. They use JSON mailboxes and a locked task list under `~/.claude/`, with one team per session and no nesting, which is exactly the tree shape the factory needs.

| Tool | What it is | License, lang | Activity | Verdict |
|---|---|---|---|---|
| [hcom](https://github.com/aannoo/hcom) | Hooks log agent activity to SQLite, `@name` messages delivered mid-turn or on wake, `hcom events` stream, MQTT relay | MIT, Rust | 577 stars, v0.7.30 (2026-10-15) | **Trial:** nearest thing to `moot`, but it wants to own agent launch |
| [AMQ](https://github.com/avivsinai/agent-message-queue) | Maildir-style queue: JSON header plus markdown body, threads, receipts, tmux wake, bridge | MIT, Go | 87 stars, v0.97.0 (2026-10-15) | **Trial:** reference design for a file-based `moot` |
| [ntfy](https://github.com/binwiederhier/ntfy) | HTTP pub/sub topics with phone push | Apache-2.0, Go | 34.9k stars, v2.31.1 (2026-10-17), mise | **Adopt:** agent to human notifications |
| [NATS server](https://github.com/nats-io/nats-server) | Single-binary pub/sub with JetStream durability, wildcards, acks | Apache-2.0, Go | 20.9k stars, v2.15.1 (2026-10-09), mise | **Trial:** optional multi-machine transport under `moot` |
| [Cotal](https://github.com/Cotal-AI/Cotal) | Coordination standard on NATS: channels, durable inboxes, role anycast, A2A envelopes, Claude Code plugin | Apache-2.0, TypeScript | 329 stars, v0.84.0 (2026-10-16) | **Watch:** copy its three address kinds |
| [Backlog.md](https://github.com/MrLesk/Backlog.md) | Markdown task files in git with an MCP server | MIT, TypeScript | 7k stars, v1.54.0 (2026-10-16) | **Trial:** if factory task state moves off GitHub Issues |
| [beads](https://github.com/gastownhall/beads) | Dependency-graph issue tracker for agents with message threads | MIT, Go | 28k stars, v1.3.1 (2026-09-30) | **Watch:** now Dolt-canonical, a heavy dependency |
| [foremerge](https://github.com/naw103/foremerge) | Semantic intent claims (symbols, schemas) that catch collisions before code is written | Apache-2.0, Rust | 541 stars, v0.5.1 (2026-10-03) | **Watch:** better than file locks; single repo |
| [concord-mcp](https://github.com/Get-Concord-AI/concord-mcp) | Claim, transfer and handoff state machine with an audit log | MIT, TypeScript | 531 stars, v0.14.1 (2026-10-17) | **Watch:** copy the handoff model; telemetry on by default |
| [git-bug](https://github.com/git-bug/git-bug) | Issues stored as git objects, with GitHub bridges | GPL-3.0, Go | 10.8k stars, v0.11.0 (2026-09-22), mise | **Watch:** git-native alternative to Issues |
| [buzz](https://github.com/block/buzz) | Nostr-relay workspace where agents have keypairs and channels | Apache-2.0, Rust | 36k stars, desktop v0.5.28 (2026-10-09) | **Watch:** needs Postgres, Redis and S3 |
| [mcp_agent_mail_rust](https://github.com/Dicklesworthstone/mcp_agent_mail_rust) | Inboxes, threads, acks, TTL file reservations, cross-project addressing | MIT plus an anti-Anthropic rider, Rust | 204 stars, v0.3.39 (2026-10-13) | **Skip:** the rider voids rights when used with Claude; read the design only |

**Notes:**

- **Dead or pivoted:** langchain agent-inbox is archived. HumanLayer's open-source code is deprecated in favor of a hosted product. claude-swarm returns 404. claude-task-master has had no push since April and uses a custom license.
- **Smaller ideas:** agent-loom's "obligations" (child owes parent a report) and the signed mailboxes in the draft [Agent Messaging Protocol](https://github.com/agentmessaging/protocol) are worth reading, even though both are tiny.

## 3. Shared knowledge bases for agents

The field is converging on the design from the trade study: markdown in git is canonical, and the index can be rebuilt. ai-memory, Remnic, Talamus, Keep the Why, Egregore and Google's Open Knowledge Format all take that shape, and Remnic recommends qmd as its search backend. Nobody does per-node lenses over an ancestor chain, so `kolmi`'s core idea is still novel. The new question is whether ai-memory, a Rust tool that already does much of the rest, is worth adopting instead of building.

| Tool | What it is | License, lang | Activity | Verdict |
|---|---|---|---|---|
| [Open Knowledge Format](https://github.com/GoogleCloudPlatform/open-knowledge-format) | Markdown plus YAML spec: `sources`, `generated`, `verified`, `status`, `stale_after` | Apache-2.0 | 1k stars, v0.2, last push 2026-08-21 | **Adopt:** as a field-name target for `kolmi` records |
| [ai-memory](https://github.com/akitaonrails/ai-memory) | Git-backed markdown wiki, rebuildable FTS index, MCP and hooks for about 20 harnesses, decay, handoffs, audit log | MIT, Rust | 9.8k stars, v3.1.1 (2026-10-17) | **Trial:** closest whole match; no lenses |
| [Entire CLI](https://github.com/entireio/cli) | Session checkpoints stored as git refs, `entire why file:line`, learnings summaries | MIT, Go | 5.2k stars, v0.11.5 (2026-10-14) | **Trial:** the `source:` field and the correction miner's input |
| [Obsidian Local REST API](https://github.com/coddingtonbear/obsidian-local-rest-api) | Plugin with a built-in MCP server: patch by heading or frontmatter, JsonLogic search | MIT, TypeScript | 3k stars, v5.5.2 (2026-10-17) | **Trial:** agent access to memex while Obsidian runs |
| [Remnic](https://github.com/joshuaswarren/remnic) | Markdown facts with temporal supersession, approval-gated corrections, qmd backend | MIT, TypeScript | 225 stars, v10.0.3 (2026-10-15) | **Watch:** same architecture; defaults to an OpenAI key |
| [Keep the Why](https://github.com/oliver-zehentleitner/keep-the-why) | Decision rationale in `context/` with status, evidence level, "revisit when", pending-confirmation | MIT, Python | 231 stars, v0.20.2 (2026-10-12) | **Trial:** the schema ideas, not the tool |
| [vrdx](https://github.com/niklas-heer/vrdx) | Decision records with TOML frontmatter, supersession-chain validation | MIT, Rust | 2 stars, v0.4.0 (2026-09-21) | **Watch:** borrow the chain check for `kolmi lint` |
| [git-ai](https://github.com/git-ai-project/git-ai) | Line-level AI attribution in git notes | Apache-2.0, Rust | 2.8k stars, v1.7.5 (2026-09-09) | **Watch:** code provenance, if blame-level attribution is wanted |
| [Agent Trace](https://agent-trace.dev/) | Cursor-led spec for AI attribution by file and line range | Spec, RFC v0.1.0 | Its GitHub repo now returns 404 | **Watch:** not knowledge provenance |
| [LadybugDB](https://github.com/LadybugDB/ladybug) | Embedded Cypher graph with FTS and vector search; the continuation of Kuzu | MIT, C++ (Rust crate) | 1.9k stars, v0.21.2 (2026-10-01) | **Watch:** graph projection if ever needed |
| [SilverBullet](https://github.com/silverbulletmd/silverbullet) | Self-hosted markdown knowledge base with frontmatter queries | MIT, TypeScript | 6.3k stars, v2.12.1 (2026-10-12) | **Watch:** web view of records from other machines |
| [Claude Code memory](https://code.claude.com/docs/en/memory) | Auto memory, `autoMemoryDirectory`, subagent `memory:` scopes | Proprietary | v2.1.302 | **Adopt:** as an input to `.agents/knowledge/`, not as the store |
| [agentmemory](https://github.com/rohitg00/agentmemory) | Memory server with version chains and decay | Apache-2.0, TypeScript | 29.6k stars, v0.9.30 (2026-10-06) | **Skip:** the database is canonical, heavy runtime |
| [Dolt](https://github.com/dolthub/dolt) | Git for SQL | Apache-2.0, Go | 24.7k stars, v2.5.0 (2026-10-17) | **Skip:** would compete with git markdown |

**Updates to tools scored on 2026-10-08:**

- **qmd:** no new release since v2.8.3, but `main` now filters search results on frontmatter fields, which lets `kolmi` push `scope` and `valid_to` filters down into qmd. Pin a commit or wait for v2.9.
- **Hindsight:** reached v1.0.0 on 2026-10-13, with a shared-bank scope for coding agents. The database is still canonical, so the verdict stands.
- **Graphiti:** v0.31.1 routes MCP tools by `group_id`, but it still defaults to OpenAI.
- **basic-memory:** added OKF export and dated facts. Still AGPL.
- **rqmd:** stalling, with no push since 2026-09-17. That weakens it as the Rust backend for `kolmi`.
- **No change:** claude-reflect and contrail-memex.

**Notes:**

- **Licenses and deaths:** Serena moved to GPL-3.0 in September. ByteRover and Cipher were archived (and were ELv2). GitNexus is noncommercial. SurrealDB is BSL. Kuzu and CozoDB are dead.
- **Steal the evidence ladder:** [MisakaNet](https://github.com/Ikalus1988/MisakaNet)'s ladder (intake, reviewed, reproduced, CI-verified, reused) is a better model than a bare `confidence` float.
- **Research:** [Governed Shared Memory](https://arxiv.org/abs/2606.24535) found that a near-duplicate gate can reject a contradicting write before contradiction detection runs. So check for contradiction before deduplicating. [Agora](https://arxiv.org/abs/2609.18094) shows git working as shared memory across 13 agents.

## 4. Agent configuration and skills management

Two facts from the earlier notes are now confirmed. Claude Code reads `AGENTS.md` natively from v2.1.277, loading every ancestor file from the cwd up at launch, so workplace `AGENTS.md` files above a repo already reach it. But it reads them only when no `CLAUDE.md` or `CLAUDE.local.md` exists anywhere in the chain, unless the project-instructions setting is `claude-md-and-agents-md`. The Bootstrap template's `CLAUDE.md` that imports `AGENTS.md` works either way. Claude Code still does not read `.agents/skills` or support Agent Plugins 1.0, so `--plugin-dir` stays the bridge.

No tool resolves an ancestor chain with per-kind merge rules. The pieces exist, though:

- rulesync renders one source tree to about 70 harnesses. `--input-roots` stacks trees in order, and its Claude plugin target writes a plugin directory that `place run` can pass to `--plugin-dir`.
- agent-perms already walks up from the cwd with a deny floor and a "ceiling" layer that only lets later layers tighten.
- fnox injects secrets.
- The home-manager modules handle the user layer.

| Tool | What it is | License, lang | Activity | Verdict |
|---|---|---|---|---|
| [rulesync](https://github.com/dyoshikawa/rulesync) | One source rendered to about 70 tools: rules, MCP, skills, hooks, permissions; lockfile, `--input-roots`, Claude plugin output | MIT, TypeScript (binaries) | 1.5k stars, v37.1.0 (2026-10-17) | **Trial:** renderer behind `place`; pin hard, seven majors in a week |
| [agent-perms](https://github.com/Mearman/agent-permissions) | `.agents/permissions.json` with walk-up merge, deny floor, codecs for Claude, OpenCode, Codex | Apache-2.0, TypeScript | 3 stars, v6.6.2 (2026-10-02) | **Trial:** matches "policy only tightens"; one maintainer |
| [fnox](https://github.com/jdx/fnox) | Secrets manager with a credential proxy and an MCP server | MIT, Rust | 2.3k stars, v1.40.0 (2026-10-16), mise | **Adopt:** already on the list; use it for MCP secrets at launch |
| [home-manager agent modules](https://github.com/nix-community/home-manager) | `programs.claude-code`, `codex`, `opencode`, `pi-coding-agent`, shared `programs.mcp` | MIT, Nix | Active (module touched 2026-10-04) | **Trial:** the root and user layer only |
| [dotagents](https://github.com/getsentry/dotagents) | `agents.toml` and lockfile; canonical `.agents/skills` symlinked into tool directories | MIT, TypeScript | 253 stars, v3.3.0 (2026-10-02) | **Watch:** closest to `.agents/`, but no layering and writes into repos |
| [agentsync](https://github.com/dallay/agentsync) | `.agents/` as source of truth, symlinks and MCP generation | MIT, Rust | 69 stars, v1.52.1 (2026-10-17) | **Watch:** Rust and `.agents/` native, but writes into repos |
| [APM](https://github.com/microsoft/apm) | Agent package manager with transitive dependencies and a lockfile | MIT, Python | 4k stars, v0.33.0 (2026-10-02), mise | **Watch:** possible skill dependency resolver |
| [skills CLI](https://github.com/vercel-labs/skills) | `npx skills` add, update and find across about 79 agents | MIT, TypeScript | 35k stars, v1.7.2 (2026-10-09) | **Watch:** de facto fetcher; telemetry on by default |
| [gh skill](https://github.com/cli/cli) | GitHub CLI preview: install, publish, search skills | MIT, Go | gh v2.102.0 | **Watch:** already installed; fetch into a workplace `.agents/skills` |
| [skillshare](https://github.com/runkids/skillshare) | Central skill store synced by symlink | MIT, Go | 2.8k stars, v0.25.13 (2026-10-16) | **Watch:** no layering |
| [1mcp agent](https://github.com/1mcp-app/agent) | Aggregates MCP servers behind one endpoint with presets | Apache-2.0, TypeScript | 518 stars, v0.39.3 (2026-10-15) | **Watch:** one MCP endpoint per node |
| [agentgateway](https://github.com/agentgateway/agentgateway) | MCP and A2A proxy with auth and policy (Linux Foundation) | Apache-2.0, Rust | 5.4k stars, v1.6.0 (2026-10-02) | **Watch:** more than a solo factory needs today |
| [ToolHive](https://github.com/stacklok/toolhive) | Runs MCP servers in containers, configures clients | Apache-2.0, Go | 2.3k stars, v0.54.0 (2026-10-14) | **Watch:** if MCP servers need sandboxing |
| [ruler](https://github.com/intellectronica/ruler) | `.ruler/` rendered to about 31 agents | MIT, TypeScript | 2.9k stars, v0.3.44 (2026-06-30) | **Skip:** rulesync is ahead |
| [ai-rules](https://github.com/block/ai-rules) | Rules for 11 agents | Apache-2.0, Rust | 139 stars, v1.7.0 (2026-05-11) | **Skip:** stalled, no `.agents/` support |

**Standards status:**

- **[AGENTS.md](https://agents.md):** stewarded by the [Agentic AI Foundation](https://aaif.io) (Linux Foundation). Nearest file wins, with no merge semantics defined.
- **[Agent Skills](https://agentskills.io/specification):** recommends `.agents/skills` at the project and user levels, project overriding user. Only skills have a real cross-client `.agents/` convention. No spec covers `.agents/mcp`, rules or hooks.
- **[Agent Plugins 1.0](https://agent-plugins.org):** covers skills and MCP only. Claude Code is not a client. The earlier note credited GitHub, but secondary sources say Vercel started it.
- **[MCP Registry](https://registry.modelcontextprotocol.io):** still described as a preview.
- **Hooks:** no cross-harness hooks standard exists.
- **What to watch:** the AAIF's AGNTCon and MCPCon run 22–23 October.

**Notes:**

- **mise:** the registry has `claude`, `codex`, `opencode`, `pi`, `apm` and `fnox`, but not rulesync. `mise mcp` (2026.10.11) exposes a project's tools, tasks and env over MCP, including real secret values, so don't hand it to agents.
- **Dead or moved:** openskills, vibe-rules, MetaMCP and iannuttall/dotagents are stale. Smithery's CLI changed hands and is now AGPL.

## Gaps worth building

- **`moot`:** none of the coordination tools above is tree-addressed, durable after an agent exits, inspectable as plain files, written in Rust and installable with mise. hcom and AMQ come closest. A design drawn from the research:
  - **Storage:** a Maildir-style spool per workplace node, written to a temp file and then renamed, with frontmatter plus a markdown body. No daemon by default.
  - **Addressing:** use the workplace tree as the address space. "Report up" means the parent's inbox, and a wildcard subscribes to a subtree. Add Cotal's three kinds: a durable unicast mailbox, a multicast topic per subtree, and an anycast role queue where one free worker claims the message.
  - **Acks and threads:** track delivered, read and resolved as separate states. Thread with `thread_id` and `in_reply_to`. Track "child owes parent a report" as an obligation, listed with an `owed` view.
  - **Delivery:** wake live Claude sessions through hooks and the cross-session socket, and send humans to ntfy. Make NATS JetStream an optional transport for cloud nodes.
  - **Envelope:** borrow A2A field names, and expose a thin stateless MCP facade.
  - **Trust:** treat every message as untrusted input. Carry sender identity, and never pass along an approval.
- **The `place` resolver:** nothing merges an ancestor chain by kind (concatenate knowledge, add capabilities with child override, tighten policy). Build the resolver in `place` and render through rulesync into a temporary plugin directory, so nothing is written into child repos.
- **A stall watchdog for interactive sessions:** Claude Code restarts stalled workflow agents and subagents, and ralphex has an idle timeout for `--print` runs. Nothing watches a live TUI session that has gone quiet without waiting for input, then kills it and runs `claude --resume`. It would be a small Rust tool, or a Guppi mechanism fed by hook timestamps or hcom idle events.
- **Budget caps under the subscription:** nothing enforces a cap on interactive or background sessions. The best available is ccusage plus OTel alerts, with `--max-budget-usd` on headless runs.
- **An open format for multi-agent plans:** Claude workflows (JavaScript), Archon (YAML), gh-aw (markdown) and Symphony are incompatible. Keep plans as markdown with validation commands (the ralphex shape), so the runner can be swapped.

## What's new since the earlier research

**Claude Code moved:**

- **Workflows:** built-in stall restarts, covered in section 1.
- **Cross-session messaging:** a local socket, on by default since v2.1.224.
- **`AGENTS.md`:** native ancestor loading is now confirmed (v2.1.277), along with its `CLAUDE.md` trap.
- **Subagent memory:** a `memory:` scope per subagent.
- **Plugins:** dependencies with version constraints and `claude plugin validate --strict`.
- **Telemetry:** OTel spans that follow the GenAI conventions.

**Standards moved:**

- **MCP 2026-07-28:** stateless, with tasks as an extension.
- **A2A:** 1.0, with an official Rust SDK.
- **OKF v0.2:** new, and a good fit for the record schema.
- **Agent Plugins 1.0:** shipped without Claude Code support.
- **Earlier claims corrected:** Agent Plugins' origin (Vercel, not GitHub), and Herdr's license (Apache-2.0, now at 44.5k stars and v0.9.5).

**New tools that matter:**

- **Orchestration:** ralphex, pueue, process-compose, ccusage and gh-aw.
- **Coordination:** hcom, AMQ, Cotal and ntfy.
- **Knowledge:** ai-memory, Entire CLI and the Obsidian Local REST API's built-in MCP server.
- **Configuration:** rulesync's `--input-roots` and plugin output, and the home-manager agent modules.

**Changes to tools covered earlier:**

- **Hindsight:** reached 1.0.
- **qmd:** frontmatter filtering is on `main`.
- **rqmd:** stalled.
- **beads and Gas Town:** moved to the gastownhall org, and beads now stores its data in Dolt.
- **Goose:** moved to AAIF and dropped its direct Claude CLI provider.
- **cmux:** server parts moved to BUSL-1.1.
- **Daytona and coder/agentapi:** both archived.
- **Serena:** went GPL.
- **ByteRover:** archived.
- **Paseo:** at v0.11.4. Its LICENSE file now mixes terms, so GitHub can't detect it. Check it before relying on the earlier Apache-2.0 reading.
- **Orca:** at v1.4.229, adding `orca worktree create` and other scripting commands.
- **Renamed repos:** pi is now `earendil-works/pi`, srt is `anthropics/sandbox-runtime`, nono is `nolabs-ai/nono`, and PR-Agent is `The-PR-Agent/pr-agent`.

**Still true:**

- **Knowledge:** no memory product does hierarchical lenses.
- **Surface:** no tool covers multi-repo tasks.
- **Coordination:** A2A is still overkill as a transport for one person.

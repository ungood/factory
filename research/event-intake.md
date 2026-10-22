# Event Intake

How to wake coding agents when something happens on GitHub, Linear or Slack, as of 2026-10-18. It covers two questions: which tools already route events to an agent session, and how events can reach a laptop that sleeps and has no public address.

Facts were checked on 2026-10-18 against each tool's current docs, with `gh api` for repository stats. Where the docs and the source disagree, or a behavior isn't documented, the note says so. Paseo Hub and Cyrus were also read from source. Earlier notes on Paseo and Orca are in [Agentic Development Environments](ades.md) and [Agentic Tools](agentic-tools.md).

## Summary

Build on Orca. Its orchestration layer (runs, tasks, dispatches, durable inboxes, `worker_done`, ask and reply) already starts, messages and settles agents in terminals I can watch and take over. What it lacks is intake: nothing turns a GitHub, Linear or Slack event into an orchestration message. Orca's own tracker asks for exactly this (see [Orca](#orca)), and nothing off the shelf does it in a way I can also use at work.

- **Only two tools keep one agent session per PR:** Paseo Hub, which runs agents locally but can't be used at work, and Claude Code's cloud auto-fix, which runs in Anthropic's cloud. Everything else starts a new session per event, or doesn't say.
- **No source queues events for long.** GitHub keeps failed deliveries for 3 days but never retries them itself. Linear retries 3 times over about 7 hours. Slack retries over about 5 minutes. A laptop that sleeps needs an always-on inbox and a sweep that reconciles from each source's API.
- **No source sends an event when a PR becomes conflicted or falls behind its base.** That has to come from the sweep.
- **Linear's Agents API needs a reply within 10 seconds** of a mention or delegation, so the always-on piece has to answer for the laptop.

The plan: a small always-on inbox (a Cloudflare Worker and queue), and a router daemon on the laptop that drains it, re-reads the real state, and acts through Orca orchestration. Events are hints. The source's current state decides what happens.

## Orca

Orca 1.4.222, checked from its CLI and its local data.

- **Orchestration:** a Run is a durable namespace with an inbox. A Task is a self-contained spec, with dependencies between tasks. A Dispatch is one attempt at a Task in one agent terminal. `orchestration worker-start` places a worktree, starts the agent and injects the prompt. The worker sends `worker_done` once, with an explicit outcome, or asks the coordinator a blocking question. The coordinator loops on `orchestration check --wait`.
- **Durability:** the state lives in SQLite in WAL mode (`~/Library/Application Support/orca/orchestration.db`). `send` proves the message is durably queued. `check` replays a batch until it's acknowledged. Mutations have receipts and can be retried with `--retry-request`. But a Run "does not schedule or place workers": there are no durable timers, so something has to be running and waiting. Agents are processes in Orca's terminals, so they're only as durable as those.
- **Automations:** schedule only (presets, cron, RRULE). A `--precheck` command can skip a run, and `--reuse-session` sends later runs to the same live session in an existing worktree. That's polling with continuity, but not events.
- **Open requests in Orca's tracker:**
  - [#21984](https://github.com/stablyai/orca/issues/21984): keep merge-required work active through review, merge and adoption. A review lifecycle keyed to the exact head commit, owners for every wait, and a "shepherd mode" for PRs I authored. Close to a spec for the router.
  - [#12400](https://github.com/stablyai/orca/issues/12400), with an open PR, [#5617](https://github.com/stablyai/orca/pull/5617): trigger automations from incoming webhooks through a local receiver. One commenter runs "a separate router daemon whose only job is to convert those webhooks into `orca orchestration worker-start` calls."
  - [#10131](https://github.com/stablyai/orca/issues/10131) (CI failure), [#11040](https://github.com/stablyai/orca/issues/11040) (GitHub issues by label), [#20646](https://github.com/stablyai/orca/issues/20646) (PR merged or closed) and [#23819](https://github.com/stablyai/orca/issues/23819) (address review-bot comments).
  - Known problems: [#23890](https://github.com/stablyai/orca/issues/23890) (heartbeats trigger prompts, silent stalls go unflagged) and [#30346](https://github.com/stablyai/orca/issues/30346) (the automation sweeper kills live sessions).

## Tools that wake agents on events

| Tool | Events | Same session per PR | Where the agent runs | Notes |
| --- | --- | --- | --- | --- |
| [Paseo Hub](https://paseo.sh/docs/hub/triggers) | Issue or PR opened, comments, labels, Slack, Discord, Linear (in source), legacy review and push | Yes, by default. A busy agent is steered | My machine, through the Paseo daemon | Apache-2.0, 55 stars, "expect data loss". GitHub needs a public URL. Can't be used at work. No CI, merge or conflict events. The docs say an offline daemon fails dispatch with `daemon_not_connected` and isn't retried; the source appears to queue it. Unresolved |
| [Claude Code cloud auto-fix](https://code.claude.com/docs/en/claude-code-on-the-web) | Review comments and CI failures on a PR, after `/autofix-pr` | Yes | Anthropic's cloud | Survives a sleeping laptop. `--teleport` gives the terminal a one-way copy. Claude only, one repo per session. Doesn't handle conflicts. Replies post as me |
| [Claude Code Channels](https://code.claude.com/docs/en/channels) | Anything an MCP plugin pushes, including a webhook receiver | Yes: into an already running local session | My terminal | Research preview. "Events only arrive while the session is open." A cleaner way to wake an agent in an Orca terminal than typing into it |
| [claude-code-action](https://code.claude.com/docs/en/github-actions) | `@claude` mentions, or any Actions event | No: each run is a new job | GitHub Actions | MIT, 9.6k stars. Takes a subscription token. Good loop guards (bots rejected unless allowed, writers only) |
| [Claude Code Routines](https://code.claude.com/docs/en/routines) | Schedule, API, PR and release events | No | Anthropic's cloud | Research preview. Events over the hourly caps are dropped |
| [Cursor](https://cursor.com/docs/cloud-agent/automations) | `@cursor`, Slack, Linear, and Automations on PR events, CI, webhooks, Sentry, PagerDuty, cron | Only for PR follow-ups, according to the forum | Cursor's cloud | Closed source. The broadest trigger set and multi-repo support |
| [GitHub Copilot coding agent](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/coding-agent/make-changes-to-an-existing-pr) | Assigned issues, `@copilot` on PRs | No, but it "remembers context" per PR | GitHub's cloud | 59-minute cap, one repo per run |
| [gh-aw](https://github.github.com/gh-aw/reference/triggers/) | Any Actions event, slash and label commands | No; memory through caches | GitHub Actions | MIT, technical preview. The Claude engine rejects subscription tokens. Writes go through a separate "safe outputs" job |
| [Cyrus](https://github.com/cyrusagents/cyrus) | Linear, GitHub, GitLab, Slack, Zulip | Linear yes. GitHub no: a new session per delivery | My machine | Apache-2.0, 856 stars. Any Claude Code plan. Events are queued only in memory. Multi-repo worktrees. Reusable transport code |
| Codex, Jules, OpenHands, Devin, Factory, Tembo, Charlie | Mentions, labels, CI | Not documented, or no | Their clouds or Actions | Terragon shut down 2026-01-16; its Apache-2.0 snapshot is reference code |

## Getting events to a laptop

### Sources

- **GitHub:** "GitHub does not automatically redeliver failed deliveries", but you can redeliver those "that occurred in the past 3 days" with `GET /repos/{owner}/{repo}/hooks/{id}/deliveries` and `POST .../deliveries/{delivery_id}/attempts` ([docs](https://docs.github.com/en/webhooks/testing-and-troubleshooting-webhooks/redelivering-webhooks)). The org and App paths weren't verified. The Events API has a latency of "30s to 6h", so it's for reconciling, not triggering.
- **Linear:** webhooks are retried "after 1 minute, 1 hour, and finally after 6 hours", and repeated failures disable the webhook until it's turned back on by hand. Signed with `Linear-Signature`; check that `webhookTimestamp` is within a minute ([docs](https://linear.app/developers/webhooks)). In the [Agents API](https://linear.app/developers/agents), a mention or delegation sends an `AgentSessionEvent`, and the agent must send an activity or set an external URL within 10 seconds or the session is marked unresponsive.
- **Slack:** HTTP events need a reply within 3 seconds and are retried immediately, after 1 minute and after 5 minutes ([docs](https://docs.slack.dev/apis/events-api/)). Socket Mode needs no public URL, but "you may lose events until you establish a connection" ([docs](https://docs.slack.dev/apis/events-api/using-socket-mode)).

### Relays

| Tool | Holds events while the laptop sleeps | Notes |
| --- | --- | --- |
| Cloudflare Worker with [Queues](https://developers.cloudflare.com/queues/configuration/pull-consumers/) | Yes: up to 14 days on the paid plan, 24 hours on free | The Worker verifies signatures. A laptop can pull over HTTP. 128 KB per message |
| [Hookdeck](https://hookdeck.com/docs/console/destinations.md) | Recorded, but resending to the CLI is manual. Whether the paid gateway delivers after reconnecting is unclear | CLI Apache-2.0. Free tier 10k events a month with 3-day retention |
| [Svix Ingest](https://docs.svix.com/ingest) | Retries for about 1.3 days | Server MIT. GitHub and Slack verification; Linear not listed |
| [Convoy](https://github.com/frain-dev/convoy) | Retries with backoff | Elastic License 2.0, not open source. Self-hosted, so it needs a public endpoint |
| ngrok, Tailscale Funnel, Cloudflare Tunnel | No | Plain tunnels |
| [smee.io](https://github.com/probot/smee.io), [`gh webhook forward`](https://github.com/cli/gh-webhook) | No | Development only. smee channels aren't authenticated |

For running a command per event, [adnanh/webhook](https://github.com/adnanh/webhook) (MIT, 12k stars) checks HMAC signatures and maps hooks to commands, which is a good model for the router's configuration. The workflow platforms (n8n, Activepieces, Windmill, Huginn, Node-RED) all work but are monoliths, and n8n's license isn't open source.

## Design for the router

1. **Inbox:** a Cloudflare Worker for each source verifies the signature, replies within the source's deadline, and queues a reference: `{source, delivery_id, entity}`. For Linear agent sessions, it also posts a holding activity within 10 seconds.
2. **Daemon:** on the laptop, under launchd. It drains the queue on wake and on a timer, removes duplicates, re-reads the entity's current state from the source, and acts through Orca orchestration: `worker-start` for new work, or a message to the Dispatch that owns the PR, issue or thread. It acknowledges a queue message only after acting.
3. **Sweep:** on wake and every few minutes, the daemon lists what changed since its cursor in each source (GitHub issues and PRs, plus failed hook deliveries; Linear issues and agent sessions; Slack channel history) and reconciles. This covers anything the inbox missed, and conflicts or a base branch moving.
4. **Conversation keys,** as in Paseo Hub: one owning agent per PR, issue or Slack thread, an allowlist of whose events count, and steering a busy agent rather than starting another.
5. **Moving to an always-on host** later means running the same daemon there, or pointing webhooks straight at it. The contract stays the same.

## Open questions

- Whether a Linear GraphQL query can re-read agent sessions, for the sweep.
- Slack Socket Mode's behavior with no connection, beyond "you may lose events".
- Paseo Hub's real offline behavior, since its docs and source disagree.
- Whether Claude Code Channels is a better way than terminal input to wake an agent in an Orca terminal, and whether it's enabled on work plans.

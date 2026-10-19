# Toolbox

The tools, defaults, and preferences that make up my software factory. Agents should treat this list as authoritative: when there's a choice of tool, library, or pattern, use what's here. When something isn't covered, ask before pulling in a default. Adding to the list is a deliberate decision.

Entries marked **Proposed** are suggestions I haven't confirmed yet.

## Principles

- **Unix philosophy:** compose small tools that each do one thing well. No monoliths, including the ones I write.
- **Off the shelf first:** prefer open source, but write my own where nothing fits.
- **Open standards over proprietary ones:** for example `AGENTS.md` over `CLAUDE.md`, and `.agents/` over `.claude/`, with only a minimal bridge where a tool requires one.
- **Easy to switch:** prefer tools that bring your own provider and don't lock me in.
- **Transparent over opaque:** I should be able to see what a tool or agent did and why.
- **Simple over clever:** a documented manual step beats automation that costs more to maintain than it saves.

## Toolchain: mise

[mise](https://mise.jdx.dev) is the entry point for every repo.

- **Tools are project-scoped:** add a missing tool to the repo's `mise.toml`, never to global config or with an ad hoc install.
- **Tasks live in mise:** build, test, lint, and release logic go in `mise run <task>`. CI workflows call mise tasks instead of inlining shell.
- **Lockfiles on:** `lockfile = true` with a committed `mise.lock`.
- **Standard task names:** `build`, `test`, `lint`, `fmt`, `dist`. Workplaces call these with `mise -C <repo> run <task>`.
- **Local overrides** go in `mise.local.toml`, which stays untracked. Never edit anything under `.git/`.

## Languages

- **Rust** is the default for CLI tools.
- **TypeScript** for web, and for tools that run on Cloudflare Workers, such as [badbot](https://github.com/ungood/badbot).
- **Python** for data work and scripts.
- **Not Go.**

### Rust defaults

Taken from [place](https://github.com/ungood/place):

- **Edition 2024**, toolchain pinned in `mise.toml` with `clippy` and `rustfmt` components.
- **CLI parsing:** `clap` with derive.
- **Errors:** `thiserror` for typed errors, `miette` for user-facing reports.
- **Config files:** TOML, edited with `toml_edit` so comments and formatting survive.
- **Tests:** unit tests in Rust; behavior specs in Gherkin run by `cucumber-rs` against the real binary.
- **Proposed:** `insta` for snapshotting large outputs, with snapshot accepts treated as spec edits.
- **Proposed:** `cargo-deny` to check licenses and advisories, and `cargo-machete` to catch unused dependencies.

### TypeScript defaults

Taken from the cyc-seattle repos:

- **Runtime:** Node 22 with pnpm, both pinned in `mise.toml`.
- **Checks:** `tsc` for types, Prettier for formatting, ESLint for lint.
- **Tests:** Vitest.
- **Shared config:** lint, format, tsconfig, and test config come from a shared package rather than being copied into each repo.

### Python defaults

- **Proposed:** `uv` for environments and dependencies, `ruff` for lint and format, a type checker (pyright or ty), and `pytest` with `pytest-bdd` for specs.

## Verification

Deterministic checks come first: formatters, linters, static analysis, type checkers, and tests. Each is a small tool with an exit code, and they compose in CI. LLM review is advisory and covers only what deterministic checks can't reach.

- **Done means:** automated tests pass, it was run for real, it got an adversarial review, and the executable specs pass.
- **Specs are executable:** Gherkin by default, run by the language's own runner. Markdown that an LLM interprets doesn't count.
- **Warnings are errors:** for example `cargo clippy --all-targets -- -D warnings` and `cargo fmt --check`.
- **One formatter entry point:** [treefmt](https://treefmt.com) runs every formatter and file linter from one config, so a repo doesn't wire up each tool separately. `treefmt --ci` is the check. Linters that need the whole project, such as `clippy` and `tsc`, stay as mise tasks.
- **Markdown** is linted with [rumdl](https://github.com/rvben/rumdl).
- **Git hooks:** [hk](https://hk.jdx.dev), installed once per machine with `hk install --global --mise`, so repos need no install step. Its pre-commit step calls treefmt, and `clippy` and `tsc` run in pre-push and CI. CI calls `mise run lint` and never depends on the hook tool. See [Hooks and formatters](../research/hooks-and-formatters.md).
- **Proposed treefmt formatters:** `shellcheck` and `shfmt` for shell, `taplo` for TOML, `actionlint` and `zizmor` for GitHub Actions, `typos` for spelling.
- **Proposed:** mutation testing with `cargo mutants --in-diff`, and diff coverage with `cargo-llvm-cov`, per the test-integrity gates in my verification research.

## Repos and git

- **License:** MIT. A `LICENSE` file ("Copyright (c) <year> Jason Walker") plus the manifest field (`license = "MIT"`). Not Apache-2.0, and not the Rust-conventional dual license.
- **Default branch:** `main`. PRs and release tags target it.
- **Merged branches:** GitHub deletes a PR's head branch when it merges (`delete_branch_on_merge`). Turn it on when creating a repo.
- **Forge:** GitHub under `ungood`. CI runs on GitHub Actions, and projects are tracked in GitHub Issues.
- **Commits:** conventional prefixes (`feat:`, `fix:`, `chore:`), signed through 1Password. Never bypass signing. Agents commit as `ungood[bot]`, which can't sign, so its commits are the one unsigned exception. PR titles are checked for the same format.
- **Releases:** automated from conventional commits. The cyc-seattle repos run semantic-release on every push to `main`. Rust releases still need a matching choice (see open questions).
- **Shared CI:** reusable workflows live in the org's `.github` repo and are pinned by tag.
- **PRs:** opened as drafts from a feature branch. Related work from one session goes in one PR.
- **No tracker refs in source:** issue keys and URLs belong in commits and PRs, not in code, comments, or `.feature` files.
- **Repos don't know their workplace:** workplace wiring (mise links, sync hooks, sibling paths) lives in the workplace. A repo must work the same wherever it's cloned.
- **Workplaces** are managed by [place](https://github.com/ungood/place) with a `place.toml`.
- **Dependency updates:** eventually a workflow inside the factory, not a third-party bot that opens a stream of PRs. The cyc-seattle repos use Renovate today.

## Secrets

- **[fnox](https://fnox.jdx.dev)** injects secrets into the environment. No `.env` files.
- **Backends per project:** 1Password by default, or a cloud store such as AWS SSM when the project runs there.
- Never ask for secrets in chat.
- Never print secret values. Inspect key names only.

## Docs and writing

- **Short and plain:** comments and docs cover non-obvious constraints. Reasoning goes in the commit message, not in comments.
- **Decisions vs. research:** settled decisions live in `docs/`. Research, comparisons and open questions live in `research/` and are temporary: once a question is settled, the decision moves into `docs/`.
- **Agent docs vs. human docs:** `AGENTS.md` holds only what an agent needs to act. Human docs live in `README.md`, `docs/`, or the tracker.
- **Style:** American spelling, no em dashes, a colon after bold bullet headings. Formal docs use flowing prose; bullets are for discrete items.

## Agents

- **Harness:** Claude Code is primary, but agent config stays tool-independent.
- **Models:** no xAI; prefer not to use OpenAI.
- **Agent environment:** [Orca](https://github.com/stablyai/orca) is the terminal and diff surface for agent work, with telemetry turned off. cmux is a close second. Paseo was a good fit but can't be used at work. See [ADEs](../research/ades.md).
- **Orchestration:** hand work off through Orca terminals and worktrees, not by messaging other sessions.
- **Workflows:** [marche](marche.md) runs long-lived agent pipelines. Workflows are Open Workflow Specification YAML, written in Pkl from marche's M2, and run by marche's Rust interpreter on Temporal. Temporal's dev server runs on the laptop as a user service. See [Workflow Languages](../research/workflow-languages.md).
- **Events:** [badbot](https://github.com/ungood/badbot) wakes the Orca agent that owns a PR when it gets a review, fails CI, conflicts or falls behind its base. The routes for this workplace are in `badbot.toml`.
- **Agent identity:** agents act on GitHub as `ungood[bot]`, badbot's GitHub App, in `ungood` repos. Their commits, PRs and comments are the bot's, so I can review and approve them. Other owners' repos and my own shell keep my identity.
- **Naming:** factory tools follow the *mise en place* kitchen theme of `mise`, `place` and `marche`. badbot is the exception: it's a pun on `ungood`.
- **Review:** agent changes are reviewed in Orca's diff view, with inline comments sent back to the agent. See [Review Tools](../research/review-tools.md).
- **Skills are project-agnostic:** project bindings go in the repo's agent docs, not in the skill.
- **Autonomy:** act until truly blocked, fix trivial issues without asking, and implement the agreed design rather than a safer subset.

## Operator setup

Personal tools that don't affect what the factory produces:

- **Terminal:** Ghostty
- **Editors:** micro in the terminal; VS Code with AI features and telemetry off
- **Containers:** Colima
- **OS:** NixOS at home, macOS at work. Nix and home-manager manage machines and dotfiles; mise manages projects. See [Nix and mise](../research/nix-and-mise.md).

## Open questions

- Whether factory tools should eventually move to the [onetruename](https://github.com/onetruename) org.
- How far Nix and mise should overlap: see [Nix and mise](../research/nix-and-mise.md).
- What the factory's own dependency update workflow looks like.
- Rust releases: release-plz (release PRs), or semantic-release with a Cargo plugin to match the TypeScript repos?
- Which proposed treefmt formatters earn a slot, and is `treefmt.toml` or treefmt-nix the config?
- Whether to stay on Ghostty outside Orca, and whether Orca's CLI covers what an agent shim for marche needs: see [Terminal Orchestration](../research/terminal-orchestration.md).

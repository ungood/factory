# marche

`marche` is the factory's workflow orchestrator: it runs long-lived, multi-step agent pipelines with human gates, loops and parallel agents. The name and architecture were settled on 2026-10-18. Nothing is built yet.

## Name

From "ça marche!", the kitchen call that an order is accepted and should be fired. It follows the *mise en place* naming of `mise` (tools) and `place` (workspace): after mise en place comes service, and marche runs it.

Related names, not yet decided:

- **`commis`:** the agent worker marche dispatches to (the Temporal activity worker). Junior cooks carry out the tasks they're given.
- **`fond`:** the shared Pkl package of base workflows that repos extend. Stocks are the base that sauces are built from.

### Availability

Checked on 2026-10-17 against crates.io, npm, Homebrew (formulae and casks), PyPI and the top GitHub repositories by stars. Domains and trademarks were not checked.

- **marche:** free on crates.io, npm and Homebrew; taken on PyPI. No relevant GitHub projects.
- **aboyeur** (runner-up, "the barker" who calls orders to stations): free everywhere.
- **Rejected because agent or workflow tools already use them:** takt ([nrslib/takt](https://github.com/nrslib/takt), agent coordination, plus a Homebrew formula), weft (an AI orchestration language), treadle and pawl (resumable workflow crates), heddle (a coding-agent runtime), escapement (an agent driven by statecharts), andon (a Lean quality system for AI work), jidoka (an agent harness), brigade (11K stars).
- **Rejected for other clashes:** expo (Expo), pass (the password manager), ratchet (a Homebrew CI/CD tool), shift (a shell builtin), yard (Ruby YARD), semaphore (Semaphore CI), garde (a large Rust validation crate).

## Architecture

```text
feature.pkl ──pkl eval──▶ feature.sw.yaml ──▶ Zigflow ──▶ Temporal
 (authoring)               (Serverless Workflow 1.0)   (runner)    (state)
```

- **Authoring: [Pkl](https://pkl-lang.org/).** Typed workflows, reusable steps (`agent()`, `Approval`, `ParallelForEach`), and base templates that repos amend. A constraint checks every jump target before anything runs.
- **Data model: [Serverless Workflow 1.0](https://github.com/serverlessworkflow/specification).** The CNCF standard, rendered from Pkl. Plus one runtime extension: a parallel for-each with `maxConcurrency` and cancel-siblings-on-failure, borrowed from Amazon States Language's `Map`.
- **Runner: [Zigflow](https://github.com/zigflow/zigflow) to start.** It compiles Serverless Workflow onto Temporal. It may later be replaced by our own interpreter if its task coverage falls short.
- **State: [Temporal](https://temporal.io/).** Durable runs, resume after crashes, human gates as signals that survive reboots, timers, and child workflows.
- **Agent steps:** activities that run a coding agent in a git worktree and return a commit SHA, never file contents, with heartbeats and retries that are safe to repeat.
- **Cancellation rule:** leaving a `do`, `fork` or `try` scope cancels everything started inside it.

[Workflow Languages](../research/workflow-languages.md) has the comparison behind these choices, the reference pipeline in each language, and the Pkl sketches.

## Reuse

- **Templates customized inside: Pkl `amends`.** Base workflows declare settings and extension points (`extraChecks`, `beforeImplement`, `afterVerify`). Repos override settings, amend single steps, and fill the extension points.
- **Black-box units: Serverless Workflow `run: workflow`.** Shared subworkflows such as `implement-task` and `open-pr`, versioned separately and run as Temporal child workflows.
- **Cross-cutting steps: `use.extensions`.** Emitted by the Pkl base, for example audit events around every agent call.
- **Review base upgrades:** Pkl flattens at author time, so CI renders and diffs the YAML when a base package changes.

## Open questions

- **Temporal on a laptop:** [Agentic Tools](../research/agentic-tools.md) rated Temporal "Skip: overkill for a laptop" on 2026-10-17. marche now depends on it. `temporal server start-dev` is a single binary, but running it all the time is a real cost. Confirm, or consider a lighter durable engine.
- **Go:** the [Toolbox](toolbox.md) says not Go, but Zigflow is Go. Using it as an off-the-shelf tool seems fine; our own interpreter would be Rust, so check the state of Temporal's Rust SDK first.
- **Zigflow coverage:** does it support `listen`, `fork`, `run: workflow` and `try` well enough for the reference pipeline?
- **Pkl schema package:** about 8 task types plus 2 macros to write, with converters to the 1.0 YAML shape.
- **Terminals:** how marche opens terminals for human gates. See [Terminal Orchestration](../research/terminal-orchestration.md).

## Next steps

- [ ] Validate the Serverless Workflow example in [Workflow Languages](../research/workflow-languages.md) against the 1.0 JSON Schema.
- [ ] Run Zigflow's quick start, then check its support for `listen`, `fork`, `run: workflow` and `try`.
- [ ] Write the Pkl schema for the task types used, plus the `Approval` and `ParallelForEach` macros.
- [ ] Write the agent activity worker: prompt and worktree in, commit SHA out, with a heartbeat.
- [ ] Run the reference pipeline end to end on `temporal server start-dev`, with the 24-hour approval timeout shortened to 1 minute.

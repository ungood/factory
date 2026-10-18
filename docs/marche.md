# marche

`marche` is the factory's workflow engine. It runs [Open Workflow Specification](https://github.com/open-workflow-specification/specification) definitions as durable workflows, with marche's own interpreter running as a Temporal workflow on Temporal's Rust SDK. It's a general engine: agents are ordinary shell steps, and anything specific to software delivery lives in the workflows.

It lives in [ungood/marche](https://github.com/ungood/marche). The design is in its [docs/design.md](https://github.com/ungood/marche/blob/main/docs/design.md), and the work is tracked in its issues. The architecture was settled on 2026-10-17, replacing an earlier plan to run definitions with Zigflow. [Workflow Languages](../research/workflow-languages.md) is the dated research behind the choice of language.

## Name

From "ça marche!", the kitchen call that an order is accepted and should be fired. It follows the *mise en place* naming of `mise` (tools) and `place` (workspace): after mise en place comes service, and marche runs it.

Related names, not yet decided:

- **`commis`:** the agent shim CLI that a workflow step could call to run an agent, which would live outside marche. Junior cooks carry out the tasks they're given.
- **`fond`:** the shared Pkl package of base workflows that repos extend. Stocks are the base that sauces are built from.

### Availability

Checked on 2026-10-17 against crates.io, npm, Homebrew (formulae and casks), PyPI and the top GitHub repositories by stars. Domains and trademarks were not checked.

- **marche:** free on crates.io, npm and Homebrew; taken on PyPI. No relevant GitHub projects.
- **aboyeur** (runner-up, "the barker" who calls orders to stations): free everywhere.
- **Rejected because agent or workflow tools already use them:** takt ([nrslib/takt](https://github.com/nrslib/takt), agent coordination, plus a Homebrew formula), weft (an AI orchestration language), treadle and pawl (resumable workflow crates), heddle (a coding-agent runtime), escapement (an agent driven by statecharts), andon (a Lean quality system for AI work), jidoka (an agent harness), brigade (11K stars).
- **Rejected for other clashes:** expo (Expo), pass (the password manager), ratchet (a Homebrew CI/CD tool), shift (a shell builtin), yard (Ruby YARD), semaphore (Semaphore CI), garde (a large Rust validation crate).

# SDLC

Status: draft, 2026-10-18.

This document describes the workflows that take an idea from an issue to deployed, verified code across my repos. They will run on [marche](marche.md). The design came out of a brainstorm on 2026-10-17 and 2026-10-18 that worked through the outer loops first, from left to right, and then the inner loops. Routines, learning, and fleet maintenance come next and aren't designed yet.

Each section separates what's decided from what's only proposed. Proposals are suggestions I haven't confirmed.

## Principles

- **Polyrepo first:** one idea usually means changes to several repos, with PRs that depend on each other, and new PRs often turn up partway through. No workflow may assume one repo or one PR.
- **The workflow state is the graph:** the set of issues, PRs and dependencies for a change lives in Temporal as workflow state. It isn't mirrored into a file in any repo. Durable state is the reason for using Temporal.
- **Outer and inner workflows:** a workplace repo has an outer workflow, and each repo has an inner workflow that the outer one can start. A workplace repo is still a repo, so it has an inner workflow of its own.
- **Standard workflows are shared:** inner workflows extend standard Pkl workflows, so every Rust project can use the same one. The standard workflows belong to the org, probably in its `.github` repo next to the shared CI workflows. They aren't part of marche.
- **Skills and workflows split the work:** interactive work, such as turning an idea into an issue, is a skill. Anything with gates, waits or ordering is a marche workflow.
- **Repos own their PRs:** each repo merges its own PRs. Dependencies between PRs are checks on the PRs themselves, not decisions made by the outer workflow.
- **Done means deployed:** a change isn't finished until it's deployed and verified.

## Idea to issue

Idea to issue is a skill, not a workflow. It's an interactive session that takes an idea until it's fully formed and then files it as an issue. The issue can go on a workplace repo, on a single project, or on a repo that has to be created first.

Ideas that aren't ready yet stay in my notes. Idea to issue is separate from `/capture`, which records an idea quickly for later. A capture goes into my notes, or becomes an issue when there's an obvious repo for it.

Once the issue exists, triage takes over.

## Triage

Every repo runs triage on its issues. Triage on a workplace repo is the "outer" triage, and it's the same workflow.

Triage decides whether an issue is actionable, whether it's in the right repo, and what happens next. The possible outcomes are:

- **Not actionable or a duplicate:** close it, or ask for what's missing.
- **Wrong repo:** move it. A small issue filed on a workplace moves down to the single repo it affects. A large one filed on a repo moves up to its workplace.
- **Needs a plan:** start planning.
- **Ready:** start implementation.
- **Unclear:** escalate to me. That includes an issue that should move up when its repo belongs to more than one workplace.

Triage should eventually start automatically when an issue opens. Issues opened by other people are untrusted input, so they need a gate of their own before triage runs. What that gate looks like isn't decided.

## Planning

Planning applies at every level. A workplace issue needs a plan, and so can a large issue in a single repo.

The plan is a narrative document, similar to Claude's plan mode. It explains what the change is, why, and how it will work across the repos involved. I review it and comment on it, possibly in Orca, and then it's attached to the issue.

Planning doesn't write feature files. Feature files are the only form requirements take, and writing them is part of implementation. There is no separate requirements document.

Each piece of the plan becomes an issue in the repo it belongs to, as a child of the original issue. Those child issues then go through each repo's own workflow.

## Coordination

Coordination is a working name for the outer workflow's job once the plan is approved and the child issues exist. It starts the inner workflows for the child issues and watches them. It has to handle two problems:

- **Discovered work:** a repo's workflow can find that it needs a change somewhere else. That becomes a new child issue.
- **Incomplete work:** a repo may not implement its issue fully. Coordination checks each finished child against the plan.

Coordination doesn't merge anything. Each repo merges its own PRs, and a PR that depends on another one carries a check that stays red until the dependency is in.

**Proposed:**

- Inner workflows report back to their parent run with marche messages, such as discovered, blocked and done, rather than the outer workflow watching GitHub.
- The dependency check is a shared CI check in the org's `.github` repo, driven by a line in the PR body such as `Depends-On: ungood/place#12`. A dependency that has to be released first often enforces itself, because the consumer's CI can't resolve a version that hasn't been published.

## Implementation

Implementation is the inner workflow. It takes an issue to code that is deployed and verified, then reports to its parent run if there is one. The steps are:

1. **Tests:** write failing tests for the issue.
2. **Build:** implement until the tests pass (see [Build loop](#build-loop)).
3. **Review:** run the agentic review.
4. **Demo:** record what the change unlocks and attach it to the PR.
5. **Approval:** approve automatically or wait for me.
6. **Merge:** once the PR's dependency checks are green.
7. **Release and deploy.**
8. **Verify:** confirm it works where it runs.
9. **Report:** tell the parent run it's done.

The workflow has more than one entry point. A Renovate PR, for example, has no issue and no tests to write, so it enters at review.

### Demos

When I say I review outcomes, I mean a PR includes a demo of the functionality it unlocks. Not every PR has one; a dependency bump doesn't. The agent decides whether a demo applies, probably through a skill in the repo that knows how to demo that kind of project.

### Approval

I review each PR, but only after its checks and agentic reviews have run.

The workflow never merges. Whoever merges a PR approves it. On my own repos, I'm the maintainer, so my merge is the approval. On a project with other maintainers, a contributor's PR needs a maintainer's approval before it can merge, but the forge enforces that with branch protection and permissions, so the workflow has no roles. It only follows the PR's state.

A deterministic policy decides which PRs are low risk enough to approve automatically. An agent can escalate a PR that the policy would approve, but it can never approve one on its own. A PR that changes existing features is high risk, so it always comes to me. The policy's actual rules aren't written yet.

### Verification

What "verified" means depends on the project:

- **CLI or library:** it's released, and a new project can install and use it.
- **Web application:** it's live, and either a smoke test passes or, at minimum, no monitors are failing.

Each standard workflow defines its own verification step, so a repo gets the right check by choosing its base workflow.

If verification fails, the workflow rolls back automatically, as a deterministic step, and opens an issue to fix the problem. That issue goes through triage like any other.

## Build loop

The build loop covers writing tests through to a PR whose checks pass.

1. **Test agent:** writes the failing tests. Not every test is a Cucumber feature; unit tests are fine where they fit. The test agent is a separate role from the implementer.
2. **Tasks:** a large issue can be split into several tasks, each run by a parallel subagent. The tasks aren't tracked in the workflow or as issues.
3. **Fast checks:** deterministic checks (formatting, linting, tests) are fast and run in a tight loop. Every task runs them before it can finish.
4. **Agentic review:** runs once, after all the tasks are done.
5. **Fix loop:** the first review uses a cheap model, the second a strong one, and there are at most three passes before escalating to me.

## PR feedback

Once a PR is waiting on me, I give feedback through PR review comments. The workflow listens for my review, addresses each comment, re-runs the checks, replies, and pushes. It goes on until the PR is merged or closed. Merging is the approval, so an approving review without a merge changes nothing.

Changes made after my review don't get another full agentic review. My review is the review.

The same agent session resumes so it keeps its context. Falling back to a fresh agent, using the PR thread as its starting point, is worth exploring for when the old session isn't available.

## Learning

Each run ends with a retrospective. A separate agent reviews how the run went (what the agent got wrong or retried, what the gate caught, what I corrected) and proposes issues: bugs to fix or features to add, in the SDLC itself or in the repo it worked on. It files each one in the repo where it belongs, and triage takes it from there. The retrospective never fails the run.

A later routine can work across runs, deduplicating proposals and promoting repeated lessons into hooks, checks and standards. That routine isn't designed yet.

## Bootstrap

The SDLC starts as the smallest workflow marche can run today and grows as marche does. Whatever marche can't do yet, I do by hand. Until the SDLC is stable, it only works on this repo and `place`, so a bad run can't break marche.

### Version 0

[`sdlc/implement.yaml`](../sdlc/implement.yaml) takes an issue through a PR and my review of it, until I merge it. The agent writes tests, implements and commits in its own worktree, a gate runs the checks, and the workflow opens the PR. Then it loops on my review, handing each round of feedback back to the same agent, until I merge or close the PR. A retrospective files issues from what went wrong, and a merge cleans up.

Each step has its own doc in [`sdlc/docs`](../sdlc/docs), named after the script it runs, and a change to a step edits only that step's doc. `implement.yaml` is the authority on the order. The steps are:

- [Prepare](../sdlc/docs/prepare.md): creates the worktree and installs the repo's tools.
- [Agent](../sdlc/docs/agent.md): runs Claude on the issue in a terminal I can watch.
- [Gate](../sdlc/docs/gate.md): runs the repo's checks on what the agent committed.
- [Pull request](../sdlc/docs/open-pr.md): pushes the branch and opens a draft PR.
- [Announce](../sdlc/docs/announce-pr.md): tells Orca and the agent about the PR.
- [Review](../sdlc/docs/review-state.md): waits for my review, until I merge or close the PR.
- [Show review](../sdlc/docs/show-review.md): shows in Orca what the review loop is doing.
- [Revise](../sdlc/docs/revise.md): sends my feedback to the agent.
- [Reply](../sdlc/docs/reply.md): pushes and replies to my feedback.
- [Retrospective](../sdlc/docs/retro.md): files issues from the run's friction.
- [Cleanup](../sdlc/docs/cleanup.md): removes the worktree after a merge.

Everything else is still manual: I triage, including the `retro` issues, plan in plan mode, review, and merge.

### Repo conventions

A repo opts in to the SDLC through its mise tasks:

- **`install`:** optional. Whatever a fresh checkout needs beyond `mise install`, such as `node_modules` or generated code. Prepare runs it.
- **`ci`:** the repo's checks. The gate runs `ci` if the repo defines it, or else `lint` and `test`, each where it exists.

This repo defines `lint` and `test`, and its [tests](../sdlc/docs/run-tests.md) run the SDLC's scripts the way a run does. [isthmia](https://github.com/cyc-seattle/isthmia) defines `install` and `ci`.

### Running it

The SDLC runs on a released marche pinned in `mise.toml`, never on the `marche/` checkout, so a broken commit there can't break the factory that's fixing it. Upgrading marche is a deliberate change to that pin.

```sh
mise run sdlc:server             # the Temporal dev server, which keeps runs across restarts
mise run sdlc:worker             # the marche worker, from the workplace root
mise run implement place 12      # take place#12 through review until I merge it
```

### Growth

Each next step depends on a marche feature:

1. **`try` and `switch`:** agentic review with the bounded fix loop.
2. **`wait`:** releasing and verifying after the merge. PR feedback already polls GitHub with `wait`.
3. **`run: workflow` and `listen`:** coordination across repos, with child issues.
4. **Schedules and event triggers:** automatic triage, and routines.
5. **Pkl:** standard workflows that repos amend.

## Not yet designed

- **Learning and compounding:** turning run records into hooks, checks and standards.
- **Fleet maintenance:** keeping all active repos converging on the current standards in [Toolbox](toolbox.md), beyond what Renovate does. If I replace hk, every active project should eventually move off it. Ideas from the 2026-10-17 discussion, none decided:
  - Scheduled drift scans that run cheap, deterministic checks on every active repo.
  - Migration campaigns that move every repo to a new standard, starting with one repo and reusing what it learned for the rest.
  - Scouts that look for improvements on a schedule and propose them in a digest instead of opening PRs.
- **Other routines:** anything scheduled rather than triggered by an issue.

## Open questions

- **What marche needs:** child workflows (`run: workflow`), messages between parent and child runs, and `listen` for PR review comments. All three are later than M1 today. Until then, PR feedback has to poll.
- **Gate for other people's issues:** what it checks, and who or what clears it.
- **The low-risk policy:** which PRs qualify for automatic approval.
- **Watching runs:** with the graph kept in Temporal, marche has to show it, for example through a `marche status` command. The Temporal UI shows history, not the graph.
- **Workflow versions:** a run pins its definition. It isn't decided which revision of a repo's workflow a new child run uses, or what happens when a change modifies a repo's own workflow.
- **Which repos are active:** fleet maintenance needs a precise definition.

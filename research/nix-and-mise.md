# Nix and mise

An open question about where Nix ends and mise begins. Captured on 2026-10-17 to revisit later.

## Where it stands

I like Nix. It's reproducible all the way down, and it already runs my NixOS machines and dotfiles through home-manager. But mise is easier for most people to pick up, and my company has started using it. A project that needs Nix to build asks every contributor, human or agent, to learn Nix first.

For now the split is:

- **Nix and home-manager** manage machines, NixOS, and dotfiles.
- **mise** manages projects: tools, tasks, env, and secrets through fnox.

A repo should build with mise alone. Nothing in a project should require Nix.

## Where the line gets blurry

**Formatting.** I like treefmt-nix, which configures treefmt and pins each formatter through Nix. Using it in a project brings Nix back in. The alternative is a plain `treefmt.toml` with the formatters installed by mise. That loses Nix's pinning but keeps the one-entry-point benefit, which is what I actually care about.

**Git hooks.** The Nix route is git-hooks.nix, which has the same problem. The mise-friendly options are:

- **lefthook:** mature and widely used, configured in YAML, runs commands in parallel and filters by glob. It knows nothing about mise, so its commands call `mise x --` or `mise run`. The cyc-seattle repos use it.
- **hk:** from the mise author. It gets tools from mise, stashes unstaged changes so fixes apply only to what's staged, and ships ready-made linter definitions. It's newer and is configured in Pkl, which is one more language to learn.
- **`mise generate git-pre-commit`:** writes a plain hook that runs one mise task, such as `mise run pre-commit`, with the staged files in `$STAGED`. There's no extra tool, but also no stash handling or parallelism beyond what the task does itself.

Decided on 2026-10-17: hk, with one step that calls treefmt. Testing showed the plain mise hook mishandles partially staged files, and hk installs once per machine without Nix. See [Hooks and formatters](hooks-and-formatters.md).

**Dev shells.** A `flake.nix` dev shell and a `mise.toml` overlap almost completely. Keeping both means keeping two lists of tools in sync.

## Options to revisit

1. **mise only for projects (current).** Simple for others and matches work. Nix stays personal.
2. **Nix as an optional layer.** A repo works with mise, and a flake is offered for people who want it. This risks drift between the two.
3. **Nix as the source, mise as the front door.** mise tasks call into Nix where pinning matters, such as `nix run .#treefmt`. Strong guarantees, but contributors need Nix installed.

## What would change my mind

- mise lockfiles and checksums proving too weak to keep builds reproducible.
- Needing a hermetic build, such as for releases or deploys, where Nix is clearly better.
- Work standardizing on one of them for repos I share with colleagues.

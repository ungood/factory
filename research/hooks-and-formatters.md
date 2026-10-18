# Hooks and formatters

A comparison of lefthook, hk, and treefmt for running formatters, file linters, and git hooks in mise-based repos. Researched on 2026-10-17 with lefthook 2.2.2, hk 2.7.0, treefmt 2.6.0, mise 2026.10.11, and Git 2.55. Every config below was run against a scratch copy of [place](https://github.com/onetruename/place) unless it says otherwise.

## The short version

Use a plain `treefmt.toml` as the one formatter entry point, with every tool pinned in `mise.toml`. Use hk as the git hook runner, with a single step that calls treefmt. Keep `clippy` and `tsc` as mise tasks. CI calls `mise run lint`, which runs `treefmt --ci` directly, so nothing in CI depends on the hook tool. The reasoning is in [Recommendation](#recommendation).

## The pieces

treefmt and the hook runners solve different problems. treefmt decides which tool runs on which file. A hook runner decides which files to hand over at commit time, and protects unstaged work while fixers rewrite them. hk overlaps with both: it ships its own linter definitions and can replace treefmt entirely.

| | lefthook | hk | treefmt |
| --- | --- | --- | --- |
| Role | Hook runner | Hook runner plus linter definitions | Formatter multiplexer |
| Language | Go | Rust | Go |
| First release | 2019 | January 2025 | 2020 |
| Stars | about 8.9k | about 1.3k | about 1.1k |
| Latest | 2.2.2 (2026-10-13) | 2.7.0 (2026-10-16) | 2.6.0 (2026-08-31) |
| Config | YAML (or TOML, JSON) | [Pkl](https://pkl-lang.org) | TOML |
| In mise | `lefthook` | `hk` | `"aqua:numtide/treefmt"` (not in the registry) |

## Shared mise.toml additions

Every approach except treefmt-nix pins the same tools. These replace `cargo fmt` in place's `lint` and `fmt` tasks.

```toml
[tools]
rust = { version = "1.99.0", components = "clippy,rustfmt" }
"aqua:numtide/treefmt" = "2.6.0"
rumdl = "0.2.79"
taplo = "0.10.0"
shellcheck = "0.11.0"
shfmt = "3.14.1"
actionlint = "1.7.12"
zizmor = "1.31.1"
typos = "1.51.1"

[tasks.fmt]
description = "Format and fix every file"
run = "treefmt"

[tasks.lint]
description = "Check formatting and file linters, then run clippy"
run = ["treefmt --ci", "cargo clippy --all-targets -- -D warnings"]
```

## (a) treefmt.toml with a mise-generated hook

```toml
# treefmt.toml
excludes = ["target/*", "*.lock", "LICENSE"]
on-unmatched = "debug"

[formatter.rustfmt]
command = "rustfmt"
options = ["--edition", "2024"]
includes = ["*.rs"]

[formatter.taplo]
command = "taplo"
options = ["format"]
includes = ["*.toml"]

[formatter.rumdl]
command = "rumdl"
options = ["check", "--fix"]
includes = ["*.md"]

[formatter.shfmt]
command = "shfmt"
options = ["--write", "--simplify"]
includes = ["*.sh"]

[formatter.shellcheck]
command = "shellcheck"
includes = ["*.sh"]
priority = 1

[formatter.actionlint]
command = "actionlint"
includes = [".github/workflows/*.yml", ".github/workflows/*.yaml"]

[formatter.zizmor]
command = "zizmor"
includes = [".github/workflows/*.yml", ".github/workflows/*.yaml", ".github/actions/**/*.yml"]

[formatter.typos]
command = "typos"
options = ["--force-exclude", "--write-changes"]
includes = ["*"]
priority = 2
```

Linters such as shellcheck, actionlint, and zizmor don't fit treefmt's [formatter spec](https://treefmt.com/latest/reference/formatter-spec/), which expects tools to rewrite files, but they work: treefmt reports any nonzero exit as a failure. `priority` orders tools that share a file, so shellcheck sees shfmt's output and typos runs last. `--force-exclude` stops typos from checking files its own config ignores (treefmt-nix sets it for the same reason).

The hook comes from [`mise generate git-pre-commit`](https://mise.jdx.dev/cli/generate/git-pre-commit.html), which writes this to `.git/hooks/pre-commit`:

```sh
#!/bin/sh
STAGED="$(git diff-index --cached --name-only -z HEAD | xargs -0)"
export STAGED
export MISE_PRE_COMMIT=1
exec mise run pre-commit
```

`$STAGED` is space-separated, includes deleted files, and fails before the first commit because `HEAD` doesn't exist yet. treefmt exits with an error on a path that doesn't exist, so committing a deletion would fail. The task should build its own list instead:

```toml
[tasks.pre-commit]
description = "Check staged files (run by the git hook)"
run = "git diff --cached --name-only --diff-filter=d -z | xargs -0 -r treefmt --fail-on-change --no-cache"
```

Each clone then needs `mise generate git-pre-commit --write --task pre-commit` once.

This is the smallest setup, but it checks the working tree, not the staged content. In testing, a clean staged hunk was blocked because an unstaged hunk in the same file was badly formatted, and treefmt rewrote the unstaged hunk. The reverse also holds: badly formatted staged code passes if the working copy has since been fixed. There's no stash and no re-staging, so the hook can only fail and leave you to `git add` again.

## (b) lefthook calling treefmt and mise tasks

```yaml
# lefthook.yml
pre-commit:
  jobs:
    - name: treefmt
      run: mise x -- treefmt --no-cache {staged_files}
      stage_fixed: true

pre-push:
  jobs:
    - name: lint
      run: mise run lint
```

```toml
# mise.toml additions
[tools]
lefthook = "2.2.2"

[tasks.install]
description = "Install git hooks"
run = "lefthook install"
```

lefthook knows nothing about mise, so commands use `mise x --` to find tools when the shell hasn't activated mise (for example in a GUI git client). With that prefix, the hook worked with only `mise` on `PATH`. [`stage_fixed`](https://lefthook.dev/configuration/stage_fixed/) hides unstaged changes, runs the job, re-stages the fixed files, and restores the hidden changes. In the partial staging test it formatted and committed the staged hunk and left the unstaged hunk untouched.

The cyc-seattle `lefthook.base.yml` avoids fixing because of [lefthook #1587](https://github.com/evilmartians/lefthook/issues/1587), where `stage_fixed` runs in two linked worktrees could swap or drop each other's hidden changes. The patch file half was fixed in 2.2.1 and the stash half in 2.2.2 (2026-10-13), so that comment is now out of date.

## (c) hk

hk is from the mise author and reads tools from mise. It evaluates Pkl with an embedded evaluator, so no `pkl` binary is needed (confirmed with `pkl` off `PATH`). On Git 2.54 or later, `hk install` writes config-based hooks (`hook.<name>.command` in git config) instead of files in `.git/hooks`, and `hk install --global` puts them in `~/.gitconfig` once per machine. In a repo without an `hk.pkl`, the global hook does nothing. `--mise` runs hooks through `mise x`.

```toml
# mise.toml additions (either variant)
[tools]
hk = "2.7.0"
```

```sh
# once per machine, for example from home-manager
hk install --global --mise
```

### Using hk's built-in linters

hk 2.7.0 ships builtins for every candidate tool (`rustfmt`, `cargo_fmt`, `cargo_clippy`, `rumdl`, `taplo_format`, `shfmt`, `shellcheck`, `actionlint`, `zizmor`, `typos`, `prettier`, `eslint`, `tsc`), but none for treefmt.

```pkl
// hk.pkl
amends "package://github.com/jdx/hk/releases/download/v2.7.0/hk@2.7.0#/Config.pkl"
import "package://github.com/jdx/hk/releases/download/v2.7.0/hk@2.7.0#/Builtins.pkl"

local workflows = List(".github/workflows/*.yml", ".github/workflows/*.yaml")

local files = new Mapping<String, Step> {
  ["rustfmt"] = Builtins.rustfmt
  ["rumdl"] = Builtins.rumdl
  ["taplo"] = Builtins.taplo_format
  ["shfmt"] = Builtins.shfmt
  ["shellcheck"] = Builtins.shellcheck
  ["actionlint"] = (Builtins.actionlint) { glob = workflows }
  ["zizmor"] = (Builtins.zizmor) { glob = workflows }
  ["typos"] = Builtins.typos
}

local clippy = new Mapping<String, Step> {
  ["clippy"] = (Builtins.cargo_clippy) {
    check = "cargo clippy --all-targets --quiet -- -D warnings"
    fix = null
  }
}

hooks {
  ["pre-commit"] {
    fix = true
    stash = "git"
    steps = files
  }
  ["pre-push"] {
    steps {
      ...files
      ...clippy
    }
  }
  ["fix"] {
    fix = true
    steps = files
  }
  ["check"] {
    steps {
      ...files
      ...clippy
    }
  }
}
```

The `lint` and `fmt` tasks become `hk check --all` and `hk fix --all`. The builtin `cargo_clippy` runs without `--all-targets` or `-D warnings`, and its fix runs `cargo clippy --fix --allow-dirty`, so it needs the override above. In exchange for Pkl, the builtins give real read-only checks (`rustfmt --check`, `rumdl check`) and parse diagnostics into file and line, which treefmt can't do.

### Using hk only to call treefmt

```pkl
// hk.pkl
amends "package://github.com/jdx/hk/releases/download/v2.7.0/hk@2.7.0#/Config.pkl"

local treefmt = new Mapping<String, Step> {
  ["treefmt"] {
    // Without a glob, an empty file list makes treefmt walk the whole tree.
    glob = "**/*"
    // treefmt has no read-only mode: --ci still rewrites files, then fails.
    check = "treefmt --ci --quiet {{files}}"
    fix = "treefmt --no-cache --quiet {{files}}"
  }
}

local clippy = new Mapping<String, Step> {
  ["clippy"] {
    glob = "**/*.rs"
    check = "cargo clippy --all-targets --quiet -- -D warnings"
  }
}

hooks {
  ["pre-commit"] {
    fix = true
    stash = "git"
    steps = treefmt
  }
  ["pre-push"] {
    steps {
      ...treefmt
      ...clippy
    }
  }
  ["fix"] {
    fix = true
    steps = treefmt
  }
  ["check"] {
    steps {
      ...treefmt
      ...clippy
    }
  }
}
```

The `glob` matters. Without it, a commit that only deletes a file ran `treefmt` with no paths, which formatted the whole repo, failed on an unrelated file, and left changes in files that weren't part of the commit. With the glob, hk skips the step. In the partial staging test, hk stashed the unstaged hunk, let treefmt fix the staged one, re-staged it, and restored the stash.

## (d) treefmt-nix, for reference

```nix
# treefmt.nix
{
  projectRootFile = "flake.nix";
  settings.global.excludes = [ "target/*" "Cargo.lock" "LICENSE" ];

  programs.rustfmt.enable = true;
  programs.rumdl-check.enable = true;
  programs.taplo.enable = true;
  programs.shfmt.enable = true;
  programs.shellcheck.enable = true;
  programs.actionlint.enable = true;
  programs.zizmor.enable = true;
  programs.typos.enable = true;
}
```

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    { self, nixpkgs, treefmt-nix }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      eachSystem = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
      treefmtEval = eachSystem (pkgs: treefmt-nix.lib.evalModule pkgs ./treefmt.nix);
    in
    {
      formatter = eachSystem (pkgs: treefmtEval.${pkgs.stdenv.hostPlatform.system}.config.build.wrapper);
      checks = eachSystem (pkgs: {
        formatting = treefmtEval.${pkgs.stdenv.hostPlatform.system}.config.build.check self;
      });
    };
}
```

This built and ran with `nix fmt`. The config is shorter, because each module carries good defaults (lock files excluded, `--force-exclude` for typos, shfmt indent settings). What it costs:

- **Nix itself:** every contributor and CI runner needs Nix, plus a `flake.lock` and a nixpkgs input to keep updated.
- **Size and time:** the wrapper's closure was about 2.7 GB on aarch64-darwin, and the first build took about 40 seconds even with every package cached.
- **Versions follow nixpkgs, not the repo:** it pulled rustfmt 1.98.1 while place's toolchain is 1.99.0, so `nix fmt` and `cargo fmt` can disagree. typos, rumdl, and zizmor were also a release behind.
- **Platform gaps:** the zizmor module marks itself [broken on Darwin](https://github.com/numtide/treefmt-nix/blob/main/programs/zizmor.nix), though it built here.

What it buys over `treefmt.toml` plus `mise.lock` is hermetic pinning and `nix flake check` running the format check in a sandbox. That's not worth making Nix a requirement.

## How they compare

**Staged files only:**

- **Plain mise hook:** sees staged names but runs on the working copy.
- **lefthook:** `{staged_files}`, filtered by `glob` and `exclude`; deleted files are left out.
- **hk:** staged files by default in hook runs; `--staged`, `--from-ref`, and `--all` on the CLI.
- **treefmt:** takes paths as arguments and has no git awareness beyond walking the tree.

**Partially staged files:** only lefthook (`stage_fixed`) and hk (`stash = "git"`) protect unstaged hunks. Both passed the same test. The plain mise hook can't.

**Auto-fix and re-stage:** lefthook re-stages with `stage_fixed`, and `fail_on_changes` can fail the commit instead. hk re-stages with `fix = true`, optionally limited by a `stage` glob. The plain hook can only fail.

**Parallelism:** treefmt runs formatters in parallel and orders tools on the same file by `priority`. lefthook runs jobs in parallel with `parallel: true`, but it doesn't know which jobs write, so a fixer and a reader can race. hk runs steps in parallel by default and uses each command's read or write effect to avoid two writers on one file.

**CI check mode:** `treefmt --ci` (no cache, fail on change). It still rewrites files before failing, which is harmless in CI but means treefmt has no dry run. `hk check --all` is read-only for builtins. lefthook isn't needed in CI; call the mise task.

**Sharing config across repos:**

- **lefthook:** [`remotes`](https://lefthook.dev/configuration/remotes/) fetch configs from a git URL pinned to a `ref`, and [`extends`](https://lefthook.dev/configuration/extends/) merges local files. The cyc-seattle repos extend a file shipped in an npm package.
- **hk:** `amends` a Pkl package URL pinned by version (published with Pkl's packaging), a relative path, or a plain HTTPS URL that hk discourages. Amending a shared base and adding a repo-only step validated cleanly.
- **treefmt:** no include or extends. Each repo carries its own `treefmt.toml`. It's around 40 lines, so copying is tolerable, and `--config-file` can't point outside the repo without breaking the rule that repos don't know their workplace.

**Whole-project linters:** treefmt can't run `clippy` or `tsc`, since it hands each tool a list of files. lefthook runs them as jobs that ignore `{staged_files}`, and hk as steps without `{{files}}`, with `workspace_indicator` to run once per `Cargo.toml`. Either way they check the whole crate, so they belong in pre-push and CI rather than pre-commit (clippy took about 11 seconds on place from a warm cache).

**Monorepos and workplaces:** treefmt treats the git root as the tree root, so each repo in a workplace formats independently, and the workplace loops with `mise -C <repo> run fmt`. lefthook has a per-job `root`. hk has `subprojects`, which pairs with mise monorepo config roots, and a global install covers every repo on the machine without the workplace wiring anything.

## Gotchas found along the way

- **treefmt isn't in the mise registry:** use `"aqua:numtide/treefmt"`.
- **treefmt's cache ignores tool config:** after changing `.rumdl.toml`, a cached `treefmt` run still passed while `treefmt --no-cache` failed. Hooks and CI should pass `--no-cache` (`--ci` implies it), and `treefmt -c` clears the cache locally.
- **hk fails fast by default:** it stopped after the first failing step. `--no-fail-fast` or `fail_fast = false` reports everything.
- **Hook PATH:** hooks run outside your shell. The mise-generated hook calls `mise run`, hk has `--mise`, and lefthook needs `mise x --` in each command.
- **Per-clone install:** lefthook and the mise-generated hook need an install step in every clone. hk's global install doesn't.
- **rumdl defaults:** the default MD013 line length of 80 failed every doc in place. Repos need a `.rumdl.toml` that matches the factory's markdown style.
- **taplo reformats:** it wrapped place's `tokio` feature array in `Cargo.toml` at 80 columns. Set the column width in a `.taplo.toml` or accept it.
- **zizmor has real findings:** it flagged place's `release.yml` with six high-severity findings, mostly actions not pinned to a hash, plus broad permissions and possible cache poisoning through `mise-action`. Turning it on means fixing those first.
- **hk moves fast:** three minor releases between October 4 and October 16, 2026. Pin it.

## TypeScript repos

The same shape works for ts-config. This `treefmt.toml` ran clean against a copy of it in under 3 seconds, while `tsc` and `vitest` stay mise tasks:

```toml
excludes = ["dist/*", "node_modules/*", "pnpm-lock.yaml", "LICENSE"]

[formatter.prettier]
command = "pnpm"
options = ["exec", "prettier", "--write", "--ignore-unknown"]
includes = ["*"]

[formatter.eslint]
command = "pnpm"
options = ["exec", "eslint", "--fix", "--no-warn-ignored"]
includes = ["*.js", "*.mjs", "*.cjs", "*.ts", "*.mts", "*.cts"]
priority = 1
```

There's no reason to migrate the cyc-seattle repos off lefthook. They could now turn on `stage_fixed`, since #1587 is fixed.

## Recommendation

Use treefmt plus mise for formatting, and hk as a thin hook runner that calls treefmt:

- **`treefmt.toml`, not treefmt-nix:** it keeps the one entry point without making Nix a requirement, and `mise.lock` covers most of the pinning that treefmt-nix provides.
- **treefmt as the entry point, not hk's builtins:** `mise run fmt`, `mise run lint`, CI, and editors all go through treefmt and never depend on the hook tool. If hk doesn't work out, swapping hook runners means changing one small file. The cost is losing hk's read-only checks and parsed diagnostics.
- **hk over lefthook:** both handle partial staging correctly, which rules out the plain mise hook. hk wins on fit: it runs tools through mise, and `hk install --global --mise` set up once from home-manager means no repo needs an install task. That matches the rule that repos don't know their workplace. Its Pkl surface stays at about 30 lines when it only calls treefmt.
- **Whole-project checks stay as mise tasks:** clippy and tsc run from `mise run lint` in pre-push and CI, not in pre-commit.

The risk is hk's age: it's under two years old and changes weekly. lefthook is the fallback, and with 2.2.2 it's equally correct for this use. The plain `mise generate git-pre-commit` hook is only enough if the hook checks rather than fixes and you accept that it judges the working copy.

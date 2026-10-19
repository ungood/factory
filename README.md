# factory

A workplace for my software factory.

## Setup

With [mise](https://mise.jdx.dev) activated in your shell:

```sh
git clone https://github.com/ungood/factory.git
cd factory
mise trust
```

Trusting `mise.toml` installs [place](https://github.com/ungood/place) and runs `place sync`, which clones the repos listed in `place.toml`. After that, every `cd` into the workplace syncs again.

To work on place itself, run `mise run link`. It builds the `place/` checkout and makes this workplace use that build.

## Docs

- [Toolbox](docs/toolbox.md): the tools, defaults, and preferences agents should use.
- [marche](docs/marche.md): the factory's workflow engine.
- [SDLC](docs/sdlc.md): the planned workflows that take an idea from an issue to deployed, verified code.

## Checks

CI runs `mise run lint` and `mise run test` on every pull request and on pushes to `main`, and `main` requires them to pass before a merge.

For earlier feedback, `hk.pkl` runs the linters on the files you commit and `mise run test` before a push. Install [hk](https://hk.jdx.dev) once per machine with `hk install --global --mise`. CI doesn't depend on the hooks.

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

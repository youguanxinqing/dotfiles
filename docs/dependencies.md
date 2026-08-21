# Dependencies and plugin declarations

Read this when adding a tool or plugin, changing a version ref, or investigating
why one machine behaves differently from another.

## Refs point at what upstream publishes, not at a commit

Use a tag where one exists, the default branch otherwise. Pinning a commit only
means new machines install progressively staler code, which makes the capability
more likely to break, not less.

Before changing a ref, compare it against `requested_ref` and `resolved_commit`
in `~/.config/herdr/plugins.json`. `herdr.scratch` was installed with no ref, so
it tracks `main`, and `main` is not the same commit as the `v1.0.1` tag —
"tidying" that into a tag swaps in code nobody has run.

## Config that references something external needs an installer in the repo

`configs/herdr/config.toml` binds 7 keys to plugin actions, and the plugin code
is gitignored — 220M does not belong in the repo. For a while nothing declared
which plugins to install, so a new machine finished `install.sh` with every one
of those keys dead.

The fix is `features/herdr/install-plugins.sh`, using the `script` installer
`cli.conf` already supports and implementing `check` / `install` / `clean`.
Follow that pattern for anything else where config points outside the repo.

## Installed ≠ right version ≠ right source

`cli_is_installed` in `install-deps.sh` runs a bare `command -v`, so
`CLI check passed` does not mean the machine matches what is declared. Two real
divergences:

- **Stale version.** herdr sat at 0.8.0 while the manifest only asked for
  "herdr". Its theme rendering differed from another machine, and the cause took
  a while to find: 0.8.2 changed theme painting (release notes #2792, #2987).
- **Wrong source.** `nvim`, `tmux`, `rg`, `fd`, `fnm`, `overmind`, and `direnv`
  all come from `/opt/nanobrew/prefix/bin`, while `cli.conf` declares brew.
  `command -v` finds them, so the brew copies never get installed.

`cli_is_managed` is the predicate that checks the real source
(`brew list --formula`, `cargo install --list`, and so on), but it is only
called on the clean path. Wiring it into `verify_manifest` would surface these;
pinning versions would need a `min_version` field in `cli.conf`.

## One trap when scripting against herdr

Running `herdr plugin list | grep -q` once per plugin under-reports. `grep -q`
exits on first match and closes the pipe, and after a few SIGPIPEs in a row
herdr reports installed plugins as missing. Query once into a variable, then
match against that.

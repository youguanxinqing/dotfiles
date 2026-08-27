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

The fix is `modules/herdr/install.sh`, using the module's `script` dependency
and implementing `check` / `install` / `clean`. Follow that pattern for
anything else where config points outside the repo.

## Our own plugin: dev link on this machine, GitHub everywhere else

`youguanxinqing.herdr-flash` (bound to `prefix+s`) is developed in
`~/Projects/herdr-pluck-flash` and `herdr plugin link`ed from there on this
machine, so `herdr plugin list` shows `[local:...]` instead of a GitHub ref.
`modules/herdr/install.sh` still declares it in `PLUGINS` so a new machine
installs it from GitHub (no tag published yet, so it tracks `main`), and it
treats an enabled `[local:]` line as satisfied so a rerun here never replaces
the dev link with a GitHub install.

## A platform can need a native integration, not just a different package

Fish is the example. macOS can use the shared Homebrew adapter, while Linux
needs a module-local script: ordinary distributions install the system Fish
package, but Omarchy installs `omarchy-fish` and keeps Bash as the login shell.
The module detects Omarchy from `/etc/os-release` instead of asking the user to
choose a mode.

`modules/fish/platform.sh` owns that detection and the bounded `~/.bashrc`
handoff. Runtime changes are backed up under
`~/.local/state/dotfiles/backups/`, and the installer method is recorded in
`~/.local/state/dotfiles/fish-installer` so an explicit clean never removes a
Fish installation that this repository did not install.

## Installed ≠ right version ≠ right source

For Homebrew formulae and casks, `cli_is_installed` requires both the declared
package and its command. A same-named command from another package manager no
longer satisfies the declaration. Other installer adapters still rely on a
bare `command -v`, so `CLI check passed` does not universally mean the machine
matches what is declared. Two historical divergences motivated the stricter
Homebrew check:

- **Stale version.** herdr sat at 0.8.0 while the manifest only asked for
  "herdr". Its theme rendering differed from another machine, and the cause took
  a while to find: 0.8.2 changed theme painting (release notes #2792, #2987).
- **Wrong source.** `nvim`, `tmux`, `rg`, `fd`, `fnm`, `overmind`, and `direnv`
  all come from `/opt/nanobrew/prefix/bin`, while their modules declare brew.
  `command -v` finds them, so the brew copies never get installed.

`cli_is_managed` remains the cleanup predicate for Cargo, npm, scripts, and
other adapters. Extending source verification beyond Homebrew would require
installer-specific checks; pinning versions would need a `min_version` key in
dependency sections.

## One trap when scripting against herdr

Running `herdr plugin list | grep -q` once per plugin under-reports. `grep -q`
exits on first match and closes the pipe, and after a few SIGPIPEs in a row
herdr reports installed plugins as missing. Query once into a variable, then
match against that.

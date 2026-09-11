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

## Our own plugins: dev link on this machine, GitHub everywhere else

`youguanxinqing.herdr-flash` (bound to `prefix+s`) is developed in
`~/Projects/herdr-pluck-flash` and `herdr plugin link`ed from there on this
machine, so `herdr plugin list` shows `[local:...]` instead of a GitHub ref.
`modules/herdr/install.sh` still declares it in `PLUGINS` so a new machine
installs it from GitHub (no tag published yet, so it tracks `main`), and it
treats an enabled `[local:]` line as satisfied so a rerun here never replaces
the dev link with a GitHub install.

`youguanxinqing.herdr-hop` (bound to `prefix+q`) is the same kind of plugin but
runs the other way round: it is installed from GitHub on this machine too, so
every machine runs the published `main`. The source checkout stays in
`~/Projects/herdr-panes` — the directory predates the rename to `herdr-hop` —
but it is no longer linked, so editing it changes nothing until the change is
pushed and the plugin reinstalled. That is the tradeoff for one source of truth;
switch it back to a dev link while iterating on the plugin itself.

The `[local:]` exemption is one-directional: it keeps a rerun from clobbering a
dev link, and therefore will not migrate a dev link back to GitHub either. Do
that by hand with `herdr plugin unlink <id>`, then rerun the module.

## A capability can straddle two repos, and the manifest only covers one

`chmarax.herdr-nvim` is two plugins with one name. The herdr half owns the nvim
sidebar (`prefix+e`) and the file picker (`prefix+o`); it is declared in
`modules/herdr/install.sh` like every other herdr plugin, so a new machine gets
those keys. The nvim half owns annotations — comment a line in the sidebar,
send every comment to an agent with `file:line`, repo and branch attached — and
it lives in `lua/custom/plugins.lua` of a different repo,
`youguanxinqing/nvim`. Nothing here installs it.

So a new machine has a working sidebar and dead `<leader>a*` keys until that
repo is cloned too, and the failure is silent: the keys simply do nothing. Do
not debug it here. `modules/herdr/install.sh` and the `prefix+e` comment in
`configs/herdr/config.toml` both say where the other half is; keep those
pointers accurate if either side moves.

Two traps on the nvim side, both found by installing it:

- That config sets `defaults = { lazy = true }`, so upstream's
  `{ "ChmaraX/herdr-nvim", opts = {} }` never loads — no event, no command, no
  keys means lazy.nvim has nothing to trigger on. The spec needs explicit
  `cmd` / `keys`.
- Its default prefix is `<leader>a`, which `folke/sidekick.nvim` already used
  for `<leader>ac` and `<leader>as`. Sidekick moved to `<leader>ak` /
  `<leader>aK`. The two plugins are not redundant: sidekick runs an agent
  inside nvim, herdr-nvim annotates for an agent running in a herdr pane.

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

## A cask whose command lives inside the .app cannot be declared as one

Sublime Text's `subl` only exists at
`/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl`. The Homebrew
cask has a `binary` stanza that symlinks it into `$HOMEBREW_PREFIX/bin`, so
`installer = brew-cask` with `command = subl` passes on a machine where brew
installed the app -- and can never pass on one where the app was dragged in from
the website. There, `brew_has cask` is false too, so a rerun tries to install
the cask over the existing app and the module fails before any hook could fix
it.

`modules/sublime-text/install.sh` is a script dependency instead: it installs
the cask only when no app bundle is present, then links
`~/.local/bin/subl` at the bundle's binary and checks that link. The result is
the same on both kinds of machine, and `subl` no longer depends on who
installed Sublime. An unmanaged `~/.local/bin/subl` is reported and left alone,
and `clean` removes only the link -- uninstalling the editor is the human's
call.

## A tool that upgrades itself needs a floor, not an equality

`hclient-cli` ships its own `upgrade`, which replaces the binary with whatever
`latest-version.json` names. Mihomo's exact-version `check` would be wrong here:
the next `install.sh` would read the mismatch as drift, re-download 42M, and put
the machine back on the release the user had just moved off.

`modules/hclient-cli/install.sh` treats `HCLIENT_CLI_VERSION` as a minimum
instead. A new machine still gets the pinned build with its published SHA-256
verified, and an already-upgraded machine is left alone. Raising the floor stays
a deliberate edit rather than something a rerun performs silently.

## One trap when scripting against herdr

Running `herdr plugin list | grep -q` once per plugin under-reports. `grep -q`
exits on first match and closes the pipe, and after a few SIGPIPEs in a row
herdr reports installed plugins as missing. Query once into a variable, then
match against that.

## A GUI app's subprocess does not inherit your shell PATH

Sublime's `Format It` command pipes SQL through `pg_format` (declared as
`installer = brew` in `modules/sublime-text/module.ini`). A Sublime launched
from the Dock or Spotlight inherits launchd's PATH -- roughly `/usr/bin:/bin` --
so `shutil.which("pg_format")` finds nothing there while the same lookup
succeeds in every terminal. The plugin therefore probes
`/opt/homebrew/bin` and `/usr/local/bin` by absolute path first and falls back
to PATH only for the `subl`-launched case. The same applies to any future
editor plugin that shells out.

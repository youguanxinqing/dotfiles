# My Dotfiles

One dotfiles setup for macOS and Linux. Capabilities are self-contained under
`modules/<name>/` and are discovered automatically. There is no central package,
feature, link, syntax-test, or module registry to update when software is added.
Ordinary links never overwrite unmanaged paths. Modules that explicitly use a
managed entry or copy back up an existing file before adopting it.

## First-time initialization

Git is the only prerequisite. Fish is installed as a module and does not need to
exist beforehand:

```bash
git clone --recurse-submodules https://github.com/youguanxinqing/dotfiles.git ~/dotfiles && ~/dotfiles/install.sh
```

The first run installs Homebrew when a selected module needs it. On Linux, it
can install Homebrew prerequisites through `apt-get`, `dnf`, or `pacman`.
Re-running `./install.sh` is safe: missing dependencies and links are added,
already-correct state is kept, unmanaged link destinations are skipped, and
managed files are reconciled with backup and drift checks.

A real install completes each module's dependencies, links, and hooks before
advancing in `order`. Fish has `order = 0`, so its Omarchy handoff is complete
before optional Homebrew taps or later plugins are attempted. If a later module
fails, fix that dependency and rerun; already-completed modules remain usable.
Dry-run keeps dependency discovery as one combined preview so package-manager
bootstrap is shown only once.

Fish's module links `~/.config/fish` and selects its integration from the
machine it is running on:

- On Omarchy, it installs the official `omarchy-fish` package, keeps Bash as
  the login shell, and adds a bounded Bash-to-Fish handoff to `~/.bashrc`.
  Existing Bash configuration is preserved and backed up before the first
  change. Re-running the installer does not create another block or backup.
- On other Linux distributions, it installs Fish with `apt-get`, `dnf`, or
  `pacman`, then offers to make Fish the login shell in an interactive run.
- On macOS, it installs Fish with Homebrew and offers the same login-shell
  switch.

The Omarchy path is detected automatically from `/etc/os-release`, with the
Omarchy command and installation directory as compatibility signals. It never
uses `chsh` to make Fish the Omarchy login shell. If a machine was changed that
way previously, restore `/usr/bin/bash` before running the installer.

```bash
./install.sh --dry-run                 # Preview a full install
./install.sh list                      # Show discovered modules and platforms
./install.sh --deps-only               # Install dependencies only
./install.sh --deps-only mihomo        # Install one module's dependencies
./install.sh --links-only              # Link configurations only
./install.sh --links-only fish tmux    # Link selected modules only
./install.sh clean --dry-run herdr     # Preview owned-state cleanup
./install.sh clean herdr               # Clean one module
./scripts/test-install.sh              # Run auto-discovered checks
```

Apply future incremental changes with:

```bash
git -C ~/dotfiles pull --ff-only && ~/dotfiles/install.sh
```

Node.js is managed by FNM, Go by goup.rs, and Rust by rustup. This repository
does not use mise.

## The module boundary

Every direct child of `modules/` with a `module.ini` is a module. All other
files are optional and discovered by convention:

```text
modules/<name>/
├── module.ini        module metadata, dependencies, and shared-source links
├── home/             Git-visible files overlaid onto $HOME automatically
├── install.sh        custom check/install/clean lifecycle, when needed
├── post-links.sh     hook after links are installed
├── post-install.sh   hook after dependencies are installed
└── test.sh           module-local test, discovered automatically
```

The existing `configs/` and `bin/` trees remain stable source locations so this
refactor does not churn every active symlink. New modules should normally put
their files under `home/`; files added below that directory need no manifest
entry. Ignored runtime state is not linked.

`scripts/module-engine.sh` owns discovery, link safety, and link ownership
state. `scripts/install-deps.sh` provides reusable package-manager adapters.
Tests under `scripts/tests/*.test.sh` and `modules/*/test.sh`, plus all
Git-visible shell scripts, are discovered without a maintained path list.

## Adding software

For a standard package, add one author-facing file:

```text
modules/jq/module.ini
```

`module.ini` uses named sections and keys instead of positional fields:

```ini
[module]
platforms = all
enabled = true
default = true
order = 10

[dependency jq]
command = jq
installer = brew
source = jq
```

The `[module]` values default to `platforms = all`, `enabled = true`,
`default = true`, and `order = 50`. A dependency section's name is its stable
dependency id; `platform` is optional and defaults to `all`.

Set `enabled = false` to park a module temporarily. Normal installs and direct
module selection will skip/refuse it, while its installed software, existing
links, and ownership records remain untouched. No cleanup is triggered by the
switch. If cleanup is eventually wanted, `./install.sh clean <module>` remains
available while the module is disabled; run it before deleting the module from
the repository. `default = false` has a different purpose: the module stays
enabled and can be selected explicitly, but is omitted from an install with no
module arguments.

Built-in installers are `brew`, `brew-cask`, `cargo`, `fnm`, `go`, `npm`, and
`rustup`:

```ini
[dependency tool-ui]
platform = macos
command = tool-ui
installer = brew-cask
source = tool-ui

[dependency tool-b]
command = tool-b
installer = npm
source = @owner/tool-b
```

For a Git checkout, release download, upstream installer, or special cleanup,
put an idempotent `install.sh` in the same module. Script sources are resolved
relative to that module:

```ini
[dependency tool-d]
command = tool-d
installer = script
source = install.sh
```

The script receives `check`, `install`, or `clean`. `check` must be read-only.
Downloads should use HTTPS, pin a version, and verify a published checksum when
available; do not use `curl | sh`.

The parser is deliberately strict and dependency-free. Sections must be
`[module]`, `[dependency <id>]`, or `[link <id>]`; duplicate/unknown keys are
errors. Values are unquoted raw text. `#` and `;` start comments only when they
are the first non-space character on a line, so URLs and paths are preserved.

## Adding configuration or commands

The preferred layout needs no link declaration:

```text
modules/tool-d/home/.config/tool-d/config.toml
modules/tool-d/home/.local/bin/tool-d-helper
```

Every Git-visible file below `home/` is linked to the corresponding path below
`$HOME`; a file added later is picked up on the next run automatically. Add a
`[link <id>]` section only for an existing shared source or when a whole
directory must be linked as one unit:

```ini
[link config]
platform = all
mode = tree
source = configs/fish
target = ~/.config/fish

[link commands]
mode = overlay
source = bin
target = ~/.local/bin

[link application-entry]
platform = linux
mode = entry
source = configs/tool/config
target = ~/.config/tool/config
template = include {source}

[link application-copy]
mode = copy
source = configs/tool/config.toml
target = ~/.config/tool/config.toml
```

`tree` links one file or directory. `overlay` recursively links Git-visible
files while leaving unrelated runtime files at the target untouched. Targets
that are not repository-owned links are reported and skipped.

`entry` writes a small regular entry file whose `template` must contain
`{source}`. That placeholder expands to a stable path below
`~/.local/share/dotfiles/current`, a single symlink to the active checkout.
Applications such as Ghostty and Kitty can therefore include the repository
configuration live without giving Omarchy a writable symlink back into Git.

`copy` atomically deploys one regular repository file. It is for applications
such as Herdr that do not support includes. The first existing target is backed
up; later runs use the last deployed fingerprint to distinguish a repository
update from runtime drift. Runtime-only drift is backed up and restored from
the repository. If both sides changed, installation stops and leaves both
files untouched for manual resolution.

Successful links are recorded under
`${XDG_STATE_HOME:-~/.local/state}/dotfiles/links.tsv`. Cleanup removes only an
exact recorded link that still points to its recorded source. Empty directories
and paths whose ownership cannot be proven are never removed automatically.
Managed entries and copies are recorded in the adjacent `managed.tsv`; their
displaced files are stored below `backups/<module>/`. Cleanup removes a managed
file only while its fingerprint still matches the last deployment, and never
removes the shared repository pointer.

On Linux, Ghostty and Kitty use managed entries. Their main configuration stays
in this repository and changes take effect through the application's normal
reload path. Herdr uses a managed copy for `config.toml`, while its plugin
configuration remains an overlay so newly tracked plugin files are discovered
without another manifest edit.

## Platform-specific modules

Platform selection belongs in the module, not in the root installer. For
example, Hammerspoon declares `platforms = macos`, so neither its application
nor its configuration is installed on Linux. Mihomo declares
`platforms = linux`.

### Mihomo on Linux

`modules/mihomo/install.sh` pins the official Mihomo release, verifies its
published SHA-256 digest, installs `~/.local/bin/mihomo`, and grants only
`cap_net_admin` and `cap_net_raw` for TUN networking. Capability verification is
repeated after every binary replacement.

The module manages `~/.config/systemd/user/mihomo.service` as a link to its own
unit. An existing unit is timestamp-backed-up first. The user service is
enabled automatically and restarted only when
`~/.config/mihomo/config.yaml` exists. Proxy configuration, providers,
subscriptions, caches, and dashboards remain machine-private. Automatic
cleanup is deliberately disabled so a cleanup command cannot silently stop the
proxy or delete its configuration.

## Private configuration

Only shareable defaults and `*.template` files belong in this public repository.
Store real proxy settings, remote hosts, credentials, and machine-specific
configuration in ignored paths such as:

- `configs/fish/local.d/`
- `configs/fish/conf.d/variables/proxy.fish`
- `configs/wezterm/config/private_remote/`

Run `./scripts/check-private.sh` before publishing. Removing a secret from the
current tree does not remove it from Git history; rewrite history and rotate the
credential if one was ever committed.

## Herdr plugins

Herdr's module owns both the command and plugin lifecycle. Exact plugin sources
and refs live in `modules/herdr/install.sh`; Git-ignored plugin code and runtime
state stay outside this repository.

## Fonts

```bash
./scripts/install-fonts.sh fonts/lxgw-wenkai
```

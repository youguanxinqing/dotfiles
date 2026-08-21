# My Dotfiles

One dotfiles setup for macOS and Linux. Core command-line tools are declared in `cli.conf`, and
optional tools are declared by their feature. Each declaration names the expected command and its
installer, so Brew, Cargo, FNM, Go, npm, rustup, and custom Git/download flows share the same
installation lifecycle. The installer never overwrites an existing configuration path.

## First-time initialization

Git is the only prerequisite because it is needed to download the installer. Fish does not need to
be installed beforehand. Initialize a new machine with one command:

```bash
git clone --recurse-submodules https://github.com/youguanxinqing/dotfiles.git ~/dotfiles && ~/dotfiles/install.sh
```

The first run installs Homebrew when a missing CLI needs it. On Linux, it also installs the required
build tools through `apt-get`, `dnf`, or `pacman`. Re-running `./install.sh` is safe: it checks each
desired command, installs only missing CLIs, and creates missing links without replacing existing
paths. Use `./install.sh --dry-run` first when an installation preview is needed.

Fish is installed through the root CLI manifest, and the installer links this repository's Fish
configuration to `~/.config/fish`. At the end of an interactive installation, the installer checks
the Fish binary and asks whether it should become the login shell. It verifies every enabled CLI
before reporting success.

Apply future incremental changes with one command:

```bash
git -C ~/dotfiles pull --ff-only && ~/dotfiles/install.sh
```

Common commands:

```bash
./install.sh --deps-only               # Install dependencies only
./install.sh --links-only              # Link all enabled configurations only
./install.sh --links-only fish tmux    # Link selected configurations only
./install.sh clean --dry-run herdr     # Preview cleanup for a disabled feature
./install.sh clean herdr               # Clean a disabled feature
```

Node.js is managed by FNM, Go versions by goup.rs, and Rust by rustup. This repository does not use
mise.

## Repository layout

The user-edited installation files stay at the repository root; implementation details stay under
`scripts/`, and optional behavior stays local to its feature:

```text
cli.conf                    Core CLI desired state
features.conf               Optional feature switches
navigation.txt              Core configuration links
features/<name>/cli.conf    Optional CLI desired state
features/<name>/navigation.txt
scripts/install-deps.sh     CLI installer implementation
scripts/installers/         Custom installers used only when a standard installer is insufficient
configs/<name>/             Application and shell configuration sources
docs/                       Conventions and pitfalls, loaded on demand from CLAUDE.md
```

Application and shell configuration lives under `configs/`; executable commands remain in `bin/`,
installer implementation in `scripts/`, and optional behavior in `features/`.

## Adding a CLI

Each non-comment line in `cli.conf` has five pipe-separated fields:

```text
platform | id | command | installer | source
```

`platform` is `all`, `macos`, or `linux`. `command` is the executable used for incremental checks.
Existing commands are always kept. When a command is missing, prefer an upstream Homebrew formula
or tap; use another adapter only when Homebrew is unavailable upstream. The built-in installers are
`brew`, `brew-cask`, `cargo`, `fnm`, `go`, `npm`, and `rustup`:

```text
all   | jq      | jq      | brew  | jq
macos | tool-ui | tool-ui | brew-cask | tool-ui
all   | tool-a  | tool-a  | cargo | tool-a
all   | tool-b  | tool-b  | npm   | @owner/tool-b
linux | tool-c  | tool-c  | go    | example.com/owner/tool-c@latest
```

If installation requires Git, a release download, or an official shell installer, use the `script`
installer instead of embedding shell code in the manifest:

```text
all | tool-d | tool-d | script | scripts/installers/tool-d.sh
```

The script receives `check`, `install`, or `clean`. `check` must be read-only and return success only
when the CLI is ready. `install` and `clean` must be safe to run repeatedly. Download scripts should
use HTTPS, pin a version, and verify a published checksum when available; do not use `curl | sh`.
After adding a declaration, run `./install.sh --dry-run` and then `./install.sh`.

## Optional features

`features.conf` controls optional feature groups. Herdr is enabled by default:

```ini
herdr=true
```

Each group lives under `features/<name>/` and may contain its own `cli.conf` and `navigation.txt`.
For example, add a Cloud feature by creating `features/cloud/` and adding `cloud=true` to
`features.conf`. Run `./install.sh` again to install its missing dependencies and create its missing
links.

Set a feature to `false` or comment it out to skip it during normal installation. This does not
automatically remove existing software or configuration. To clean it explicitly, disable it first
and run:

```bash
./install.sh clean cloud
```

Cleanup removes only symbolic links that still point into this repository and CLIs declared
exclusively by that feature. CLIs also declared by the core or another enabled feature are retained.
Brew, Cargo, npm, and custom script installers support cleanup; optional tools installed through
another method should use a custom script when automatic cleanup is required. Use `--dry-run` to
preview cleanup. Empty directories and paths whose ownership cannot be verified are never removed
automatically.

## Configuration links

The root `navigation.txt` contains core links; optional features use their own `navigation.txt`.
Fish, Kitty, WezTerm, and Ghostty link their full configuration directories. tmux links
`~/.tmux.conf`; its helper commands are published with the other commands in `~/.local/bin`. Herdr links only `config.toml`, preserving its
plugin and runtime directories. Existing unmanaged destinations are reported and skipped; the
installer never overwrites them or blocks the remaining incremental work.

`bin/` is the source of personal commands. The installer links each executable into
`~/.local/bin`, and Fish adds that standard directory to `PATH`, so commands keep working when the
repository is cloned elsewhere.

## Private configuration

Only shareable defaults and `*.template` files belong in this public repository. Store real proxy
settings, remote hosts, credentials, and machine-specific configuration in ignored paths such as:

- `configs/fish/local.d/`
- `configs/fish/conf.d/variables/proxy.fish`
- `configs/wezterm/config/private_remote/`

Run the privacy check before publishing changes:

```bash
./scripts/check-private.sh
```

This check catches common mistakes only. Removing a sensitive value from the current tree does not
remove it from Git history; rewrite the history and rotate the affected credential if a secret was
ever committed.

## Herdr plugins

```bash
herdr plugin install thanhdat77/herdr-navigator --ref v0.3.5 --yes
herdr plugin install cinco/herdr-grep-nvim --ref v1.0.3 --yes
herdr plugin install ntindle/herdr-resurrect --yes
herdr plugin install persiyanov/herdr-reviewr --ref v0.29.0 --yes
herdr server reload-config
```

The Herdr plugins require `fzf`, `rg`, `bat`, `nvim`, `node`, and `gh`. They are declared in the root
CLI manifest, and FNM manages Node.

## Fonts

```bash
./scripts/install-fonts.sh fonts/lxgw-wenkai
```

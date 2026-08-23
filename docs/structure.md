# Module structure and links

Read this when changing directory structure, module discovery, or link behavior.
Safety rules in `CLAUDE.md` still apply and outrank everything here: a
restructure can relink paths a running machine depends on.

## Modules are the extension boundary

`install.sh` discovers `modules/*/module.ini`. A module owns its platform,
dependencies, links, lifecycle hooks, and tests. Adding a capability must not
require a new root switch, manifest entry, syntax path, or test-runner entry.

`enabled = false` parks the entire module without changing existing machine
state. It is a selection gate, never an uninstall signal. Explicit cleanup is
still allowed so a module can be cleaned before its directory is eventually
deleted. `default = false` is only for enabled, opt-in modules.

On a real install, numeric `order` controls a complete module lifecycle:
dependency installation, links, `post-links.sh`, then `post-install.sh`. Only
after those steps succeed does the next module begin. Put machine bootstrap
capabilities before optional tooling; Fish uses `order = 0` so a later download
failure cannot prevent its terminal handoff. Dry-run emits one combined
dependency plan and never executes hooks.

Prefer `modules/<name>/home/` for new files. Its contents overlay `$HOME` by
relative path, so adding another file later requires no metadata change.
Discovery uses Git-visible files (`--cached --others --exclude-standard`), which
keeps ignored logs, caches, credentials, and generated state out of the link
set.

`[link <id>]` sections in `module.ini` exist for stable shared sources such as
the legacy `configs/` and `bin/` trees. Use `tree` when the application expects
a complete directory and does not write runtime state inside it. Use `overlay`
when tracked config and untracked runtime state must coexist.

Two managed-file modes cover paths that another system owns or rewrites:

- `entry` generates a regular loader file from a one-line `template`; its
  `{source}` placeholder points through `~/.local/share/dotfiles/current` to a
  repository file. Use it when the application supports `include`,
  `config-file`, or an equivalent directive.
- `copy` deploys one regular file atomically. Use it only when the application
  has no include mechanism. A recorded fingerprint distinguishes repository
  updates, runtime-only drift, and two-sided conflicts.

Both modes back up an unmanaged target before first adoption. Runtime-only
drift is also backed up before the repository version is restored. A two-sided
change is never resolved automatically. This explicit behavior is why managed
modes may adopt an existing file while `tree` and `overlay` continue to skip
unmanaged paths.

## Ownership is explicit

Each successful or already-correct link is recorded in the state file. Cleanup
requires all three values to agree: module, target, and current source. A target
that has been replaced or repointed is skipped. Parent directories are never
removed because the installer cannot prove ownership of everything inside.

Managed files have a separate state file with their kind, source, target, and
last deployed fingerprint. Cleanup likewise requires an exact fingerprint.
Backups and both state files live below
`${XDG_STATE_HOME:-~/.local/state}/dotfiles`; none belongs in Git.

Repository-owned links can be relinked after a source move. Unmanaged files,
directories, and links are skipped. `readlink` comparisons are literal; a clone
reached through a case-variant or non-canonical path can therefore look
different even when the filesystem resolves it to the same place.

Managed entries avoid checkout-path churn through the one repository pointer.
When migrating the former Linux terminal layout, the installer may replace an
immediate directory link only after resolving it inside the current repository.
An unrelated directory link remains untouched.

## Keep runtime state outside the repository

`configs/` and module `home/` directories hold only what a human wrote. Logs,
sockets, sessions, plugin downloads, and registries remain in the real home
directory and should be ignored before they are created in the repo.

When moving a legacy config, remember that `git mv` does not carry ignored
machine-local files. Inspect ignored files separately, preserve the ones that
represent intentional local configuration, and leave generated state behind.
Run `scripts/check-private.sh` after the move.

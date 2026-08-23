# Module structure and links

Read this when changing directory structure, module discovery, or link behavior.
Safety rules in `CLAUDE.md` still apply and outrank everything here: a
restructure can relink paths a running machine depends on.

## Modules are the extension boundary

`install.sh` discovers `modules/*/module.ini`. A module owns its platform,
dependencies, links, lifecycle hooks, and tests. Adding a capability must not
require a new root switch, manifest entry, syntax path, or test-runner entry.

Prefer `modules/<name>/home/` for new files. Its contents overlay `$HOME` by
relative path, so adding another file later requires no metadata change.
Discovery uses Git-visible files (`--cached --others --exclude-standard`), which
keeps ignored logs, caches, credentials, and generated state out of the link
set.

`[link <id>]` sections in `module.ini` exist for stable shared sources such as
the legacy `configs/` and `bin/` trees. Use `tree` when the application expects
a complete directory and does not write runtime state inside it. Use `overlay`
when tracked config and untracked runtime state must coexist.

## Ownership is explicit

Each successful or already-correct link is recorded in the state file. Cleanup
requires all three values to agree: module, target, and current source. A target
that has been replaced or repointed is skipped. Parent directories are never
removed because the installer cannot prove ownership of everything inside.

Repository-owned links can be relinked after a source move. Unmanaged files,
directories, and links are skipped. `readlink` comparisons are literal; a clone
reached through a case-variant or non-canonical path can therefore look
different even when the filesystem resolves it to the same place.

## Keep runtime state outside the repository

`configs/` and module `home/` directories hold only what a human wrote. Logs,
sockets, sessions, plugin downloads, and registries remain in the real home
directory and should be ignored before they are created in the repo.

When moving a legacy config, remember that `git mv` does not carry ignored
machine-local files. Inspect ignored files separately, preserve the ones that
represent intentional local configuration, and leave generated state behind.
Run `scripts/check-private.sh` after the move.

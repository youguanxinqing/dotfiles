# CLAUDE.md

**Safety comes first.** This repo acts directly on a machine that is doing real
work. A mistake here does not fail a build — it destroys running work. When
safety conflicts with anything else in this file, safety wins.

Purpose: **restore capability on a new machine, not reproduce one machine's
state.** Pane layout, sessions, and logs are not in scope.

Layout, install commands, and manifest field formats are in `readme.md`.

## Safety: compute the blast radius first

- **Before killing a process or deleting a directory, count what dies.**
  `herdr server stop` went into a plan before anyone knew it meant 62 panes and
  a running agent. Run `herdr workspace list` / `tmux list-sessions` first, then
  decide whether it is worth it.
- **Before deleting a file, confirm nothing holds it with `ps -ax -o comm=`, in
  the moment before deleting.** `pgrep` cannot see a herdr server launched by
  absolute path — `pgrep -f herdr` misses it too. Trusting `pgrep` deleted a
  socket out from under a live server and killed 12 keybinds. A check from
  minutes ago does not count; processes get restarted.
- The order is **back up → dry-run → verify → then delete.** `install.sh
  --dry-run` and `--links-only <name>` exist for this.
- Clean up through a tool's own commands (`herdr-scratch close`,
  `herdr workspace close`) rather than editing its registry or `session.json` by
  hand.
- **Keep diagnostics read-only.** Probes start services: one
  `tmux -L <sock> list-keys` sweep spawned 40 servers, so what it read back was
  what it had just created. When a probe mutates something, clean up and say so.
- This repo is public. Run `scripts/check-private.sh` before pushing. It scans
  `--cached --others --exclude-standard`, so orphaned directories left by a
  restructure get scanned too — clear the orphans rather than loosening the
  check. Keep secrets out through `.gitignore`; proxy addresses, ssh domains,
  and `.claude/settings.local.json` already have rules, and a new file of that
  kind gets its rule before it lands.

## Config in the repo, runtime state in ~/.config

`configs/` holds only what a human wrote. What a program writes stays outside:
logs, sockets, `session.json`, plugin code (herdr's plugins are 220M), any
registry.

The test: does it still mean anything on a different machine? If not, it stays
out of the repo.

## Write scripts for bash 3.2

A new machine has no other bash — `cli.conf` does not declare one — so
`#!/usr/bin/env bash` resolves to macOS's `/bin/bash` 3.2. `test-install.sh`
runs an extra `/bin/bash -n` pass, because the bash on PATH may be 5.x and will
happily accept bash 4+ syntax that 3.2 rejects. Add new scripts to both lines.

## Load on demand

- Changing directory structure, or adding or editing a `navigation.txt`
  mapping → `docs/structure.md`
- Adding a tool or plugin, changing a version ref, or investigating why one
  machine behaves differently from another → `docs/dependencies.md`
- Confirming a change actually took effect, or a long-running process still
  serving the config it read at startup → `docs/verifying.md`

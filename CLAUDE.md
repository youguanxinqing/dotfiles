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

A new machine has no other bash yet, so `#!/usr/bin/env bash` resolves to
macOS's `/bin/bash` 3.2. `scripts/test-install.sh` automatically discovers every
Git-visible shell script and runs an extra `/bin/bash -n` pass, because the bash
on PATH may be 5.x and will happily accept bash 4+ syntax that 3.2 rejects.

## Every feature: all three machines, fast, without being asked

The user works on this Mac, the Air, and NixOS at once. "Add X" means X works
from a pane or shell on any of them and feels instant. Both are part of done,
not follow-ups to wait for the user to report.

- **Cross-machine.** Before writing code, decide how the feature behaves when
  it starts on another host and when its target is on another host (a tab, a
  session, a file there). Test both on nixos or the Air, in the minimal
  environment a script really gets there, not only on the Mac.
- **Performance.** Time each step the user feels (key → something visible,
  Enter → result) with real numbers before handing it over. Count network
  round trips and fresh connections: a new `rex -S` or ssh connection over
  Tailscale costs 100–300 ms though the round trip is 10 ms. Reuse
  connections, run independent calls in parallel, cache what doesn't change,
  and show local results before remote ones arrive.
- Put both in the report: where it was tested, and the timings.

## Load on demand

- Changing directory structure, module links, or module discovery →
  `docs/structure.md`
- Adding a tool or plugin, changing a version ref, or investigating why one
  machine behaves differently from another → `docs/dependencies.md`
- Confirming a change actually took effect, a long-running process still
  serving the config it read at startup, or a NixOS rebuild that succeeds
  without picking up an edit → `docs/verifying.md`
- Changing Rex keys or actions (`modules/rex`) → `modules/rex/CLAUDE.md`:
  every action must also work, fast, in a remote-host pane

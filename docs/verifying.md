# Verifying that a change took effect

## Correct config ≠ live config

A long-running process reads its config once at startup and then holds it. One
migration hit this three times:

- **tmux server** — the one up since Aug 5 still pointed at the deleted
  `~/.tmux/bin/*`, so `prefix+h` and `prefix+f` failed silently. The file on
  disk had been correct the whole time.
- **herdr server** — a 0.8.0 server against a 0.8.2 CLI, protocol 19 against
  20, `compatible: no`, and all 12 CLI-backed keybinds dead.
- **Hammerspoon** — still holding the pre-rename `herdrToast`, so notifications
  fell back to terminal-notifier without complaint.
- **herdr's *other* server** — `herdr status` only reports the default session,
  so it said `compatible: yes` while the `herdr-scratch` backing session, a
  separate server up since Sep 2, was still on 0.8.2: protocol 20 against the
  0.9.0 client's 22. The only symptom was `prefix+p` doing nothing. After a
  herdr upgrade, check every row of `herdr session list`, not just the default
  — `herdr --session <name> status` is what reveals
  `private_protocol_compatible: no`, and `herdr plugin log list` records the
  action that failed (`timed out starting backing Herdr session`).
  Fixing it costs the session's contents: `herdr session stop herdr-scratch`
  killed 25 shells, and their scrollback was already unreachable through the
  mismatched protocol.

## A watcher does not see through a symlink

Sublime reloads a plugin when something changes in `Packages/User/`. Our files
live there as symlinks into the repository, so editing the repository file
produces no event in the watched directory and the old code keeps running --
`format_it.py` had the fix on disk for six minutes while the editor still
rejected the input it was written for.

**Restarting Sublime is the only reload this repository has actually verified.**
`hot_exit` defaults to `always`, so windows and unsaved buffers come back.
Repointing the link with

```
./install.sh clean sublime-text && ./install.sh sublime-text
```

is worth trying first, but whether the watcher acts on it is unproven: APFS here
does not update `atime`, so "did Sublime re-read this file" is not observable
from outside, and no test since has separated the two.

Editing through the deployed path (`~/Library/Application Support/Sublime
Text/Packages/User/...`) does not help either -- it is the same symlink, so the
write still lands in the repository directory the watcher is not looking at.

## Verify against a freshly started process

- **tmux** — start a clean server on its own socket:
  `tmux -L <new socket> -f <conf> new-session -d`, then read `list-keys`. On the
  default socket **`-f` does nothing**: an existing server read its config at
  startup and ignores the flag, so you are reading the old bindings. To fix a
  live server in place without killing it, use `tmux source-file`.
- **herdr** — `herdr status server` reports `version`, `protocol`, and
  `compatible`. `herdr config check` passing only means the file parses; it says
  nothing about what the running process is using.
- **Hammerspoon** — `hs -c 'hs.reload()'`, then
  `hs -c 'return type(<function>)'` to confirm the new definition is live.
- **fish** — verify `command -v` and variables in a fresh login shell
  (`fish -l -c '...'`), not in the current one.

## Do not let probes contaminate what you are measuring

Running `tmux -L <sock> list-keys` across a directory of socket files starts a
new server for every dead socket, so the "config" you read back is what you just
created — one sweep started 40 of them. Establish which sockets actually have a
process behind them first, with `ps -ax -o pid=,comm=`.

That command choice matters beyond tmux: `pgrep` misses processes launched by
absolute path, which is how a live herdr server got mistaken for a stopped one.
See the safety rules in `CLAUDE.md`.

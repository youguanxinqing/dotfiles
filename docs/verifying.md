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

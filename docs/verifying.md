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

## On NixOS the build reads a Git revision, not your working tree

This one is not about a stale process. The file on disk is correct, the rebuild
succeeds, and the package is still missing.

`/etc/nixos` consumes this repository as a flake input, declared as a Git
submodule whose `.gitmodules` URL is GitHub, with `self.submodules = true` in
its `flake.nix`. Nix therefore resolves the submodule **by revision from
GitHub**. Anything that lives only in the working tree -- including a brand-new
module directory -- never reaches the store.

Adding `jj` cost two rebuilds before this was found. `nixos-rebuild switch`
exited 0 both times and `/run/current-system` was re-created (mtime moved), but
the symlink target was byte-identical, so nothing had changed. `command -v jj`
stayed empty while the edit sat in `nix/home.nix`.

`--refresh` does not help: it invalidates flake input caches, not a `rev`-pinned
submodule. `nixos-rebuild` never reads the checkout at all.

Read the input Nix will actually use, which is the fastest way to tell this
apart from a stale process:

```bash
P=$(nix flake metadata --json | jq -r .path)
grep -n 'jj' "$P/vendor/dotfiles/nix/home.nix"
```

A local commit that is not on GitHub yet fails loudly instead of silently:

```
error: Cannot find Git revision '60cf6a3...' in ref 'master' of
       repository 'https://github.com/youguanxinqing/dotfiles.git'
```

The order is: commit here, run `scripts/check-private.sh`, push, then advance the
gitlink in `/etc/nixos` (`git add vendor/dotfiles && git commit`) and rebuild.
A push that is rejected because the remote moved is normal on a long-lived
machine -- rebase onto `origin/master` rather than forcing, then confirm the
commit still touches what you meant.

### The installer path does not work this way

None of the above applies to macOS or to Linux without Nix. There, `install.sh`
links straight out of the checkout, and discovery does not consult GitHub at all:
`discover_modules` globs `modules/*/module.ini`, and `scripts/module-engine.sh`
links files from `git ls-files --cached --others --exclude-standard`, a
combination that includes untracked-but-not-ignored files. Editing a config or
adding a module directory and rerunning `./install.sh` takes effect
immediately, with no commit and no push.

So the push requirement is a property of the NixOS flake input, not a rule of
this repository. Do not "fix" a NixOS staleness report by telling someone to
commit when they are on the installer path.

A machine that builds locally can drop the push step by pointing the input at
the checkout instead of GitHub:

```nix
dotfiles = {
  url = "git+file:///etc/nixos/vendor/dotfiles";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

That trades a network round-trip for a hardcoded path, and still requires a
commit -- `git+file` filters through Git exactly like the GitHub URL does.

## Do not let probes contaminate what you are measuring

Running `tmux -L <sock> list-keys` across a directory of socket files starts a
new server for every dead socket, so the "config" you read back is what you just
created — one sweep started 40 of them. Establish which sockets actually have a
process behind them first, with `ps -ax -o pid=,comm=`.

That command choice matters beyond tmux: `pgrep` misses processes launched by
absolute path, which is how a live herdr server got mistaken for a stopped one.
See the safety rules in `CLAUDE.md`.

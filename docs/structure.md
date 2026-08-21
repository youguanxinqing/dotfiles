# Directory structure and mapping

Read this when changing the structure under `configs/`, or adding or editing a
`navigation.txt` mapping.

Safety rules in `CLAUDE.md` still apply, and outrank everything here: a
restructure deletes and relinks paths a running machine depends on.

## navigation.txt maps directories by default

A directory map is what guarantees files added under it get managed
automatically and nothing is silently left behind. A program writing runtime
files into the same directory is fine — the allowlist in `.gitignore` decides
what gets committed.

Use a per-file map only where a directory map breaks, and **record the reason in
the manifest**. The one known exception, with its reason, is at the top of
`features/herdr/navigation.txt`: `herdr plugin install` pre-creates
`plugins/config/<id>/`, and `install.sh` links after installing dependencies, so
by link time the target directory already exists and gets reported as
`Skipped unmanaged path`.

## The linker compares paths as strings

`install.sh` compares `readlink` output against `$ROOT` as a raw string, so a
case-variant but equivalent path (`~/projects/dotfiles` against
`~/Projects/dotfiles`) is reported as `Skipped unmanaged path` and passed over.
The link then looks like it was never created, when it was actually skipped.

Check the literal string with `readlink` first when debugging this. The real fix
is resolving both sides through `realpath` before comparing.

## git will not move what gitignore hides

When restructuring, `git mv` only touches tracked files. The gitignored
machine-local layer stays where it was — and it is often the layer that
matters. `configs/fish/local.d/local.fish` is the only thing on this machine
that puts `/opt/nanobrew/prefix/bin` on PATH, and `nvim`, `tmux`, `rg`, `fd`,
`fnm`, `overmind`, and `direnv` all resolve there.

Moving the fish config means carrying `local.d/`, `conf.d/pyenv.fish`, and
`conf.d/variables/proxy.fish` across by hand, then verifying `command -v` in a
fresh login fish.

Leave `fish_variables` behind. Its `fish_user_paths` holds dead
`/home/<name>/...` paths from another machine, and
`configs/fish/conf.d/paths.fish` owns PATH now.

After the move the old directories become orphans: untracked, and no longer
matched by the new ignore rules. Delete them, or `check-private.sh` will scan
the logs inside them and fail on the home paths there.

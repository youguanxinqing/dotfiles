# Fish configuration

`conf.d` files use numeric prefixes because Fish sources them in lexical order:
Homebrew first, the stable user path next, dynamic toolchains after that, and
aliases/theme last.

`~/.local/bin` is the only repository-owned static PATH entry. Repository
commands, `cargo install` binaries, `go install` binaries, and optional Flutter
entry points are published there. Homebrew, fnm, goup, and rustup keep their
managed runtime paths because they carry package-manager or version-selection
semantics that a flat directory of links cannot replace.

fzf is installed by the `fzf` module through Homebrew. Fish automatically calls
`functions/fish_user_key_bindings.fish`, which sources `fzf --fish` and enables:

- `Ctrl-R`: fuzzy command-history search with classic one-based sequence numbers
- `Ctrl-T`: fuzzy file/directory insertion
- `Alt-C`: fuzzy directory change

The sequence number is only picker metadata; it is removed before the selected
command is inserted into the command line.

Machine-local overrides belong in `~/.config/fish/local.d/local.fish`.

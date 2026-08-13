# My Dotfiles

## Usage

```bash
git clone git@github.com:youguanxinqing/dotfiles.git ~/dotfiles
cd ~/dotfiles/scripts/
bash install [FLAG]
```

## Herdr Plugins

Config is tracked, the build tree is not. On a fresh machine:

```bash
herdr plugin install thanhdat77/herdr-navigator --ref v0.3.5 --yes
herdr plugin install cinco/herdr-grep-nvim --ref v1.0.3 --yes
herdr plugin install ntindle/herdr-resurrect --yes
herdr plugin install persiyanov/herdr-reviewr --ref v0.29.0 --yes
herdr server reload-config
```

Needs `fzf`, `rg`, `bat`, `nvim` (grep-nvim), `node` (resurrect), `gh`/`glab` (reviewr PR tab).

## Install Fonts

```bash
sh scripts/install-fonts.sh
```


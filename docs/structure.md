# 目录结构与映射

动 `configs/` 的目录结构、或者加/改 `navigation.txt` 的时候看这份。

## navigation.txt 默认按目录映射

按目录映射才能保证目录下新增的文件自动被管起来、不漏。程序往同一个目录写运行时
文件不影响 —— `.gitignore` 里那份白名单负责筛该提交哪些。

按单文件映射只在按目录会坏的时候用，并且**要在 manifest 里写下原因**。唯一已知的
例外和它的原因写在 `features/herdr/navigation.txt` 开头：`herdr plugin install`
会先把 `plugins/config/<id>/` 建好，而 `install.sh` 是先装依赖后建链接，等轮到
建链接时目标目录已经存在，会被判成 `Skipped unmanaged path` 跳过。

## linker 是按字符串比路径的

`install.sh` 拿 `readlink` 的输出直接和 `$ROOT` 比字符串，所以大小写不同但等价的
路径（`~/projects/dotfiles` vs `~/Projects/dotfiles`）会被判成
`Skipped unmanaged path` 静默跳过 —— 链接看着"没建"，其实是被跳了。

排查时先 `readlink` 看一眼实际字符串。想根治就让它两边都先过 `realpath`。

## gitignore 的东西，git 不会帮你搬

重构目录时 `git mv` 只动被跟踪的文件，被 ignore 的机器本地层留在原地 —— 而它往往
是关键的那一层：`configs/fish/local.d/local.fish` 是这台机器上唯一把
`/opt/nanobrew/prefix/bin` 加进 PATH 的地方，`nvim` `tmux` `rg` `fd` `fnm`
`overmind` `direnv` 全靠它。

搬 fish 配置要手动带上 `local.d/`、`conf.d/pyenv.fish`、
`conf.d/variables/proxy.fish`，然后在新起的 login fish 里 `command -v` 验一遍。

`fish_variables` 不要搬回去：里面的 `fish_user_paths` 存着别的机器留下的
`/home/<name>/...` 死路径，`configs/fish/conf.d/paths.fish` 现在负责 PATH。

搬完之后旧目录会变成孤儿（未跟踪、也不再被新的 ignore 规则命中）。清掉它们，
否则 `check-private.sh` 会扫到里面的日志。

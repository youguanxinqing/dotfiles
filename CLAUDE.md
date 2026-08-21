# CLAUDE.md

主旨：**在新机器上恢复能力，不是复刻某台机器的状态。**

仓库结构、装机命令、manifest 字段格式看 `readme.md`。下面这些是从坑里捞出来的，
动配置结构之前先过一遍。

## 动手之前：先算爆炸半径

这个仓库是直接作用在一台正在干活的机器上的，改错了不是编译不过，是当场丢工作。

**要杀进程、要删目录之前，先数清楚会死掉什么。** `herdr server stop` 写进计划的
时候没人知道它等于 62 个 pane 加一个正在跑的 agent。先
`herdr workspace list` / `tmux list-sessions` 数一遍，再决定值不值。

**删文件之前用 `ps -ax -o comm=` 确认没有进程在用它，而且要在删的前一刻确认。**
`pgrep` 看不见按绝对路径起的 herdr server（`pgrep -f herdr` 一样看不见），照着
`pgrep` 判「没在跑」，结果把 socket 从活着的 server 底下删掉了，12 个键当场全死。
几分钟前查过不算 —— 进程随时会被重新拉起来。

顺序是**备份 → dry-run → 验证 → 才删**。`install.sh --dry-run` 和
`--links-only <name>` 就是为这个准备的；迁移前那份备份目录是后来唯一还能拿回
`local.d/` 和 `fish_variables` 的地方。

清理走工具自己的路径（`herdr-scratch close`、`herdr workspace close`），
不要手改它的 registry / session.json。

**诊断保持只读。** `tmux -L <socket> list-keys` 探活会顺手把 server 起起来 ——
一次探针起了 40 个 tmux server，读到的全是自己刚建的东西，不是现场。探针有副作用
就收拾干净，并且说出来。

## 能力优先

目标是「这些键、这些命令能用」，不是目录树逐字节一样。面板布局、session、日志
都不在恢复范围内。

版本引用指向上游发布的东西：有 tag 用 tag，没有 tag 的跟默认分支。钉死 commit 只会
让新机器装到越来越旧的代码，能力反而更容易坏。

换 ref 之前先跟 `plugins.json` 里的 `requested_ref` / `resolved_commit` 对一下：
`herdr.scratch` 当初是不带 ref 装的（走 `main`），而 `main` 和 `v1.0.1` tag 不是
同一个 commit —— 想当然改成 tag 就换了一份没验过的代码。

## 配置进仓库，运行时状态留在 ~/.config

`configs/` 只放人写的配置。程序自己写的留在外面：日志、socket、`session.json`、
插件代码（herdr 插件 220M）、各种 registry。

判断标准：换台机器还有意义吗？没有就不进仓库。

## navigation.txt 默认按目录映射

按目录映射才能保证目录下新增的文件自动被管起来、不漏。程序往同一个目录写运行时
文件不影响 —— `.gitignore` 里那份白名单负责筛该提交哪些。

按单文件映射只在按目录会坏的时候用，并且**要在 manifest 里写下原因**。唯一已知的
例外和它的原因写在 `features/herdr/navigation.txt` 开头。

linker 是拿 `readlink` 的输出按字符串比的，所以大小写不同但等价的路径
（`~/projects/dotfiles` vs `~/Projects/dotfiles`）会被判成
`Skipped unmanaged path` 静默跳过。想根治就让它两边都先过 `realpath`。

## gitignore 的东西，git 不会帮你搬

重构目录时 `git mv` 只动被跟踪的文件，被 ignore 的机器本地层留在原地 —— 而它往往
是关键的那一层：`configs/fish/local.d/local.fish` 是这台机器上唯一把
`/opt/nanobrew/prefix/bin` 加进 PATH 的地方，`nvim` `tmux` `rg` `fd` `fnm`
`overmind` `direnv` 全靠它。

搬 fish 配置要手动带上 `local.d/`、`conf.d/pyenv.fish`、
`conf.d/variables/proxy.fish`，然后在新起的 login fish 里 `command -v` 验一遍。

## 配置引用了外部东西，仓库里就要有人装它

`configs/herdr/config.toml` 把 7 个键绑在插件上，而插件代码是 ignore 的 —— 曾经
没有任何东西声明该装哪些插件，新机器上装完这些键全是死的。补法见
`features/herdr/install-plugins.sh`，走的是 `cli.conf` 已有的 `script` installer。

## 装了 ≠ 版本对 ≠ 来源对

`install-deps.sh` 的 `cli_is_installed` 只跑 `command -v`，所以
`CLI check passed` 不代表这台机器和声明一致：herdr 曾停在 0.8.0（主题和另一台
不一样），七个工具实际来自 nanobrew 而不是 manifest 里写的 brew。
`cli_is_managed` 查的是真实来源，但目前只用在 clean 路径。

## 配置改对了 ≠ 已经生效

长驻进程启动时读一次配置就一直拿着。这一条踩了三回：tmux server（8 月 5 号起的，
还指着已删掉的 `~/.tmux/bin/*`）、herdr server（0.8.0 配 0.8.2 CLI，protocol
不兼容，12 个键全死）、Hammerspoon（还留着改名前的 `herdrToast`）。

验证一律对着新起的进程做：`tmux -L <新 socket>`、重启 server、`hs.reload()`。
`herdr config check` 通过只说明文件能解析，不说明跑着的进程在用它。

## 硬约束

- 脚本按 bash 3.2 写。新机器上没有别的 bash（`cli.conf` 也没声明），
  `#!/usr/bin/env bash` 解析出来就是 macOS 自带的 `/bin/bash` 3.2。
  `test-install.sh` 会额外用 `/bin/bash -n` 过一遍 —— 光靠 PATH 上的 bash 不行，
  本机那个可能是 5.x，抓不到 bash 4+ 的写法。新增脚本记得加进那两行。
- 仓库是公开的，push 前跑 `scripts/check-private.sh`。它扫的是
  `--cached --others --exclude-standard`，也就是**跟踪的加上没被 ignore 的未跟踪
  文件** —— 重构留下的孤儿目录会一起被扫（旧 herdr 日志里全是 `/Users/<name>/`
  路径）。所以先把孤儿清掉再 push，别去放宽这个检查。
- 私密的东西靠 `.gitignore` 拦在外面，不靠记性：代理地址、ssh domain、
  `.claude/settings.local.json` 里的公司项目路径都已经有规则。新增这类文件时
  先补规则再落盘。

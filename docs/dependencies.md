# 依赖与插件声明

加工具、加插件、改版本 ref，或者在查「为什么这台机器和另一台不一样」的时候看这份。

## ref 指向上游发布的东西，不钉 commit

有 tag 用 tag，没 tag 的跟默认分支。钉死 commit 只会让新机器装到越来越旧的代码，
能力反而更容易坏。

换 ref 之前先跟 `~/.config/herdr/plugins.json` 里的 `requested_ref` /
`resolved_commit` 对一下：`herdr.scratch` 当初是不带 ref 装的（走 `main`），而
`main` 和 `v1.0.1` tag 不是同一个 commit —— 想当然改成 tag 就换了一份没验过的
代码。

## 配置引用了外部东西，仓库里就要有人装它

`configs/herdr/config.toml` 把 7 个键绑在插件上，而插件代码是 ignore 的
（220M，不该进仓库）—— 曾经没有任何东西声明该装哪些插件，新机器上装完这些键
全是死的。

补法见 `features/herdr/install-plugins.sh`：走 `cli.conf` 已有的 `script`
installer，实现 `check` / `install` / `clean` 三个动作。以后再加这类"配置引用了
仓库外的东西"的东西，照这个模式声明。

## 装了 ≠ 版本对 ≠ 来源对

`install-deps.sh` 的 `cli_is_installed` 只跑 `command -v`，所以
`CLI check passed` 不代表这台机器和声明一致。实际踩到的两种偏差：

- **版本旧**：herdr 停在 0.8.0 而声明只说"要有 herdr"，主题渲染和另一台不一样，
  查了半天才发现是 0.8.2 改了主题（见 release notes 的 #2792 / #2987）。
- **来源不对**：`nvim` `tmux` `rg` `fd` `fnm` `overmind` `direnv` 七个实际来自
  `/opt/nanobrew/prefix/bin`，而 `cli.conf` 声明的是 brew。`command -v` 找得到，
  于是永远不会去装 brew 那份。

`cli_is_managed` 查的才是真实来源（`brew list --formula`、`cargo install --list`
等），但目前只用在 clean 路径。想让 `verify_manifest` 也报这类偏差，就把它接上去；
想卡版本，`cli.conf` 需要加一个 `min_version` 字段。

## 一个写脚本时会踩的坑

`herdr plugin list | grep -q` 每个插件跑一遍会漏报：`grep -q` 命中就退出、把管道
关掉，连着几次 SIGPIPE 下来 herdr 会说某些明明装了的插件没装。查一次存进变量再
匹配。

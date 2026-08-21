# 验证改动是否真的生效

## 配置改对了 ≠ 已经生效

长驻进程启动时读一次配置就一直拿着。这一条在一次迁移里踩了三回：

- **tmux server**：8 月 5 号起的那个，还指着已经删掉的 `~/.tmux/bin/*`，
  `prefix+h` / `prefix+f` 静默失效。文件本身早就是对的。
- **herdr server**：0.8.0 的 server 配 0.8.2 的 CLI，protocol 19 对 20，
  `compatible: no`，12 个走 CLI 的键当场全死。
- **Hammerspoon**：还留着改名前的 `herdrToast`，通知静默退回 terminal-notifier。

## 验证对着新起的进程做

- tmux：`tmux -L <新 socket> -f <conf> new-session -d` 起一个干净的 server 看
  `list-keys`。**在默认 socket 上 `-f` 是无效的** —— 已有 server 只在启动时读一次
  配置，`-f` 会被忽略，你看到的是旧绑定。活着的 server 用
  `tmux source-file` 就地重载，不用杀。
- herdr：`herdr status server` 看 `version` / `protocol` / `compatible`。
  `herdr config check` 通过只说明文件能解析，不说明跑着的进程在用它。
- Hammerspoon：`hs -c 'hs.reload()'`，然后 `hs -c 'return type(<函数名>)'` 确认新
  定义在了。
- fish：起一个新的 login fish（`fish -l -c '...'`）验 `command -v` 和变量，
  不要在当前 shell 里验。

## 探针别把现场搞脏

对着一堆 socket 文件跑 `tmux -L <sock> list-keys` 会给每个死 socket 起一个新
server，于是"读到的配置"全是自己刚建出来的，不是现场 —— 一次这样起了 40 个。
先确认哪些 socket 背后真有进程（`ps -ax -o pid=,comm=`）再查。

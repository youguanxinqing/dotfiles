# CLAUDE.md

主旨：**在新机器上恢复能力，不是复刻某台机器的状态。** 面板布局、session、日志
都不在恢复范围内。

仓库结构、装机命令、manifest 字段格式看 `readme.md`。

## 安全：先算爆炸半径

这个仓库直接作用在一台正在干活的机器上，改错了不是编译不过，是当场丢工作。

- **杀进程、删目录之前，先数清楚会死掉什么。** `herdr server stop` 写进计划的时候
  没人知道它等于 62 个 pane 加一个正在跑的 agent。先 `herdr workspace list` /
  `tmux list-sessions` 数一遍，再决定值不值。
- **删文件前用 `ps -ax -o comm=` 确认没人在用，而且要在删的前一刻确认。**
  `pgrep` 看不见按绝对路径起的 herdr server（`pgrep -f herdr` 也看不见）；照着它
  判「没在跑」，socket 被从活着的 server 底下删掉，12 个键当场全死。几分钟前查过
  不算 —— 进程随时会被重新拉起来。
- 顺序是**备份 → dry-run → 验证 → 才删**。`install.sh --dry-run` 和
  `--links-only <name>` 就是为这个准备的。
- 清理走工具自己的命令（`herdr-scratch close`、`herdr workspace close`），
  不手改它的 registry / session.json。
- **诊断保持只读。** 探针会把服务起起来（`tmux -L <sock> list-keys` 起过 40 个
  server），读到的就成了自己刚建的东西。有副作用就收拾干净，并且说出来。
- 仓库是公开的，push 前跑 `scripts/check-private.sh`。它扫
  `--cached --others --exclude-standard`，重构留下的孤儿目录会一起被扫 ——
  清孤儿，不要放宽检查。私密内容靠 `.gitignore` 拦（代理地址、ssh domain、
  `.claude/settings.local.json` 都已有规则），新增这类文件先补规则再落盘。

## 配置进仓库，运行时状态留在 ~/.config

`configs/` 只放人写的配置。程序自己写的留在外面：日志、socket、`session.json`、
插件代码（herdr 插件 220M）、各种 registry。

判断标准：换台机器还有意义吗？没有就不进仓库。

## 写脚本按 bash 3.2

新机器上没有别的 bash（`cli.conf` 也没声明），`#!/usr/bin/env bash` 解析出来就是
macOS 自带的 `/bin/bash` 3.2。`test-install.sh` 会额外用 `/bin/bash -n` 过一遍 ——
PATH 上那个可能是 5.x，抓不到 bash 4+ 的写法。新增脚本记得加进那两行。

## 按任务展开

- 动目录结构、加或改 `navigation.txt` 映射 → `docs/structure.md`
- 加工具、加插件、改版本 ref、查「为什么这台和另一台不一样」 → `docs/dependencies.md`
- 确认改动是否真的生效、长驻进程还在用旧配置 → `docs/verifying.md`

---
name: gitlab-mr-review
description: Use when the user wants to AI-review a GitLab Merge Request. Triggers on phrases like "review 这个 MR", "帮我 review !123", "看一下别人的 MR". Reads the diff, produces numbered issues in chat, then lets the user pick which ones to fix (and how). AI is a reviewer + on-demand fixer; it never posts to GitLab.
---

# Skill: gitlab-mr-review — Reviewer 辅助

**哲学**：AI 读代码、给出带编号的 review 结果，**只输出在对话里**，不发到 GitLab。用户看完结果后自己决定哪些要修、怎么修；AI 按指示去改代码。

## 语言策略

- **Issues / 与用户对话**：匹配用户本轮对话使用的语言
- 修复若产生 commit，**一律英文 conventional commits**

## 执行顺序

| Phase | 动作 |
|---|---|
| 0 | 定位目标 MR（iid），取 `diff_refs` |
| 1 | 读 `git diff base...head`，跨文件 Grep 关联上下文 |
| 2 | 多维度 review，生成带编号的 issues |
| 3 | 在对话里列表展示给用户 |
| 4 | 用户挑要修的编号 + 修复方式（中断确认） |
| 5 | 按指示修复选中的条目 |

## Phase 0：定位 MR

两种触发情形：

**情形 A：用户已 checkout 了对应分支**
```bash
glab-api mr-find-by-source "$(git rev-parse --abbrev-ref HEAD)" | jq '.[0]'
```

**情形 B：用户说 "review !123" 或提供了 URL**
```bash
glab-api mr-view 123
```

从 MR 对象抽：`iid`、`source_branch`、`target_branch`、`diff_refs.{base_sha,head_sha}`、`web_url`。

情形 A 找不到对应 open MR 时：
```
当前分支 <branch> 没有对应的 open MR。
请 `glab mr checkout <iid>` 切到目标分支后重试，或直接说 "review !<iid>"。
```
**停止流程**。

## Phase 1：收集 diff + 跨文件上下文

1. `git fetch origin "$SOURCE_BRANCH" "$TARGET_BRANCH"` 确保本地有两端
2. `git diff "$BASE_SHA..$HEAD_SHA"` 按文件分段读
3. 对可疑改动 Grep 全仓，例："这个函数签名变了，还有哪些调用点没改？"
4. 读 `CLAUDE.md`、`project-rules/*.md` 等仓库规则文件作为审查基准

## Phase 2：多维度 review

每个 issue 至少含：`severity`、`category`、`file`、`line`、`title`、`description`。可选 `suggestion`。

**评级规则**：
- `[必修]`：有明确触发条件 + 具体失败后果。说不清怎么炸 → 降级 `[建议]`
- `[建议]`：能更好但不会出问题
- `[信息]`：客观说明，不需要行动

**维度**：正确性 / 安全 / 性能 / 可读性 / 兼容性。

**条数上限：默认 ≤15 条。** 宁少勿滥，提高信噪比。

## Phase 3：展示给用户

用文本把全部 issues 铺陈出来（含 positives + 跨文件建议），每条带唯一编号：

```
已识别 N 条关注点：

#1  [必修] 正确性  path/to/file.ts:42
    短标题 — 详细说明
    建议：...
#2  [建议] 可读性  path/to/other.ts:118
    ...
#3  [信息] 兼容性  api/handler.go:77
    ...

—— 整体观感 ——
做得好的：...
跨文件建议：...
```

展示完后，提示用户：**告诉我要修哪几条（如 "修 1,3" / "全部修" / "都不用修"），需要的话也说明怎么改。**

`AskUserQuestion` 可用时优先弹勾选菜单（multiSelect=true），每条 issue 一个选项（label 形如 `#3 [必修] path:line — 短标题`，description ≤100 字），超过 4 条分批问。

**结束本轮**，等用户决定。

## Phase 4：解析用户选择

按用户回复组装修复清单。允许多条编号（"1,3,5" / "1 3 5" / "1-3" / "全部"）。用户对某条给了具体修复方向就照办；没给就用 issue 里的 `suggestion`，拿不准的修复方案先简述再动手。

## Phase 5：修复

对选中的每条 issue 改代码。改完报告：改了哪些文件、怎么改的、为什么。不发任何东西到 GitLab。

## 依赖

- `bin/glab-api`（仅用于读 MR 元数据 + diff）
- `git`、`jq`
- `$LB_GITLAB_TOKEN` 或 glab 已登录

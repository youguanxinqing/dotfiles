import os
import time

import sublime
import sublime_plugin

# 笔记库的根目录就叫 scratch，跟侧边栏里那个同名。它下面那些带序号的目录是
# 第一级（00_important / 01_tmp / 02_需求 / 99_other），按日期建的目录都落在
# 这些下面 —— 所以这个命令要分两步问：先问落哪一支，再问叫什么。
_SCRATCH = "scratch"

# 名字前缀沿用库里已有的写法：026.09.14 —— 年份留后三位、月和日补零。
_STAMP_FORMAT = "%Y.%m.%d"


class NewScratchDirCommand(sublime_plugin.WindowCommand):
    def run(self):
        root = _scratch_root(self.window)
        if root is None:
            sublime.status_message("New Scratch Dir: no %s/ folder is open" % _SCRATCH)
            return
        parents = _child_dirs(root)
        if not parents:
            sublime.status_message("New Scratch Dir: %s/ has no subfolder" % _SCRATCH)
            return
        # 回调里用不到 self：Sublime 每次执行都新建一个 command 实例，
        # 把状态挂在 self 上能跑通但没必要，参数直接传下去。
        self.window.show_quick_panel(
            parents, lambda index: _ask_name(self.window, root, parents, index))


def _ask_name(window, root, parents, index):
    # Esc、点面板外面、面板开着时目录被删光 —— 都走这里，什么都不建。
    if index < 0:
        return
    stamp = _stamp()
    # caption 把将要建出来的路径摊开：日期已经填好，人只管往后接名字，
    # 也能一眼看出用的是哪天。
    window.show_input_panel(
        "%s/%s/%s" % (_SCRATCH, parents[index], stamp),
        "",
        lambda text: _create(window, os.path.join(root, parents[index]), stamp, text),
        None,
        None,
    )


def _create(window, parent, stamp, text):
    name = text.strip()
    if not name:
        # 空回车只会留下一个 026.11.01/ 的裸目录，回头分不清是谁的，当取消处理。
        sublime.status_message("New Scratch Dir: cancelled, empty name")
        return
    if "/" in name or ":" in name:
        # 放 "/" 就等于放 "../.." 出去建目录；":" 在 Finder 里会被显示成 "/"，
        # 建出来的目录名跟侧边栏里看到的不是一个东西。
        sublime.status_message('New Scratch Dir: name cannot hold "/" or ":"')
        return

    target = os.path.join(parent, stamp + name)
    if os.path.isdir(target):
        # 同一天同名再来一次是手快，不是要第二个 —— 刷一下侧边栏指给人看就行。
        window.run_command("refresh_folder_list")
        sublime.status_message("New Scratch Dir: %s/ already exists" % name)
        return
    try:
        os.makedirs(target)
    except OSError as error:
        # 只读、磁盘满、iCloud 那边正占着，都把系统自己的话透出来。
        sublime.status_message("New Scratch Dir: %s" % error)
        return

    # 侧边栏靠轮询，刚建好的目录不会马上出现，不刷一下人以为没建成又按一次。
    window.run_command("refresh_folder_list")
    sublime.status_message(
        "New Scratch Dir: %s/%s" % (os.path.basename(parent), stamp + name))


def _scratch_root(window):
    # 侧边栏可能直接开在 scratch/ 上，也可能开在它的上一级 work-sync/ 上。
    # folders() 拿的是侧边栏的根，跟当前文件在第几级无关。
    for folder in window.folders():
        if os.path.basename(folder.rstrip(os.sep)) == _SCRATCH:
            return folder
        nested = os.path.join(folder, _SCRATCH)
        if os.path.isdir(nested):
            return nested
    return None


def _child_dirs(root):
    try:
        names = os.listdir(root)
    except OSError:
        return []
    return sorted(name for name in names if os.path.isdir(os.path.join(root, name)))


def _stamp():
    # %Y 出来是四位（2026），库里那份是三位（026），所以截掉头一个字符。
    # 想要完整年份就去掉 [1:]，代价是新目录排不到 026.* 那一堆里。
    return time.strftime(_STAMP_FORMAT)[1:]

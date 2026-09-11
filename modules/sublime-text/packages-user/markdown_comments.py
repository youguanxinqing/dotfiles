import os
import shutil
import subprocess

import sublime
import sublime_plugin

_APP_RELATIVE = "MDComments.app/Contents/MacOS/MDComments"


class MarkdownCommentsCommand(sublime_plugin.TextCommand):
    def run(self, edit):
        binary = _mdc()
        if binary is None:
            sublime.status_message("Markdown Comments: MDComments is missing")
            return
        # 不等它退出：mdc 打开的是 GUI，一直到窗口关掉才返回。
        subprocess.Popen([binary, self.view.file_name()])

    def is_enabled(self):
        # mdc 只收磁盘上的路径，没存过的 buffer 给不出来。
        # 返回 False 这条命令就不会出现在命令面板里。
        return bool(self.view.file_name())


def _mdc():
    # 从 Dock 启动的 Sublime 只继承 /usr/bin:/bin，/opt/homebrew/bin/mdc 那条软链不在 PATH 上，
    # 而且那条链是手工建的，新机器上不一定有 —— 先按 app bundle 的固定位置找真实文件。
    for directory in (os.path.expanduser("~/Applications"), "/Applications"):
        path = os.path.join(directory, _APP_RELATIVE)
        if os.access(path, os.X_OK):
            return path
    return shutil.which("mdc")

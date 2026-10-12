import os
import shutil
import subprocess
import time

import sublime
import sublime_plugin

# 图片放在当前文件同级的这个目录里，链接也按这个相对路径写 —— 笔记连同图片
# 一起移动/复制都不会断。写死仓库根的 assets/ 就得算相对路径，跨几级目录之后
# 那串 ../../ 谁都读不懂。
_IMAGE_DIR = "assets"

# 解析一次就够，pngpaste 不会在一次会话里换地方。只缓存成功：没装的时候
# 留 None，人 brew install 完不用重启 Sublime 就能用。
_binary = None


class PasteImageCommand(sublime_plugin.TextCommand):
    def run(self, edit):
        path = self.view.file_name()
        if path is None:
            # 没落盘就没有"同级目录"，图片无处可放，相对链接也无从算起。
            sublime.status_message("Paste Image: save the file first")
            return

        binary = _pngpaste()
        if binary is None:
            sublime.status_message("Paste Image: pngpaste is missing (brew install pngpaste)")
            return

        directory = os.path.join(os.path.dirname(path), _IMAGE_DIR)
        os.makedirs(directory, exist_ok=True)
        target = _new_path(directory)

        process = subprocess.Popen(
            [binary, target], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        out, err = process.communicate()
        if process.returncode != 0:
            # 剪贴板里是文本时也走这条路（"No image data found on the clipboard"），
            # 把 pngpaste 自己的话透出去比我再编一句准。
            message = (err or out).decode("utf-8", "replace").strip()
            sublime.status_message("Paste Image: %s" % (message or "pngpaste failed"))
            return

        link = "![](%s/%s)" % (_IMAGE_DIR, os.path.basename(target))
        # 倒着写回去。多光标时前一处变长会把后面 region 的偏移全带偏（跟 format_it 同一个理由）。
        for region in reversed(list(self.view.sel())):
            self.view.replace(edit, region, link)


def _new_path(directory):
    # 同一秒粘第二张会撞名，而 pngpaste 是直接覆盖 —— 前一张已经被文档引用了，
    # 覆盖就是不声不响地改内容。撞了就往后加序号。
    stamp = time.strftime("%Y%m%d-%H%M%S")
    candidate = os.path.join(directory, "%s.png" % stamp)
    index = 1
    while os.path.exists(candidate):
        candidate = os.path.join(directory, "%s-%d.png" % (stamp, index))
        index += 1
    return candidate


def _pngpaste():
    global _binary
    if _binary is None:
        _binary = shutil.which("pngpaste") or _login_shell_which("pngpaste")
    return _binary


def _login_shell_which(command):
    # 从 Dock 启动的 Sublime 继承的是 launchd 的 PATH（这台机器上 launchctl getenv PATH
    # 是空的，也就是 /usr/bin:/bin:/usr/sbin:/sbin），brew 的目录不在里面，所以
    # shutil.which 只在"从终端 subl 起来"的那种进程里找得到。退回去问登录 shell：
    # PATH 本来就是它配出来的，不用把 /opt/homebrew 写死在这儿。
    #
    # -l 和 -c 分开写，fish 不保证认 -lc 这种合并写法。
    # timeout 是必须的：TextCommand 跑在 UI 线程上，登录 shell 卡住就是 Sublime 卡住。
    shell = os.environ.get("SHELL") or "/bin/sh"
    try:
        out = subprocess.check_output(
            [shell, "-l", "-c", "command -v %s" % command],
            stderr=subprocess.DEVNULL, timeout=5)
    except (OSError, subprocess.SubprocessError):
        return None
    # 取最后一行并确认真能执行：shell 把它解析成函数或 alias 时，command -v
    # 吐出来的是一段定义，不是路径。
    lines = out.decode("utf-8", "replace").strip().splitlines()
    return lines[-1] if lines and os.access(lines[-1], os.X_OK) else None

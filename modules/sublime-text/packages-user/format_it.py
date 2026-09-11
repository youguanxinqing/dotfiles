import json
import os
import re
import shutil
import subprocess

import sublime
import sublime_plugin

# 只看起手关键字。代价明确：以 select 开头的普通英文段落也会被送去 pg_format，
# 它不报错，只会排出一段奇怪的缩进 —— 撤销一下就回来了。
_SQL_HEAD = re.compile(
    r"\s*(with|select|insert|update|delete|merge|create|alter|drop|truncate"
    r"|explain|grant|revoke|begin|commit|rollback|vacuum|analyze)\b",
    re.IGNORECASE)

_SYNTAX = {
    "json": "Packages/JSON/JSON.sublime-syntax",
    "sql": "Packages/SQL/SQL.sublime-syntax",
}

# json.loads('null') 也返回 None，拿 None 当"不是 JSON"会把这两种情况混在一起。
_NOT_JSON = object()


class FormatItCommand(sublime_plugin.TextCommand):
    def run(self, edit):
        regions = [r for r in self.view.sel() if not r.empty()]
        if not regions:
            regions = [sublime.Region(0, self.view.size())]

        # 先算完再动 buffer：格式化一半、原样留一半，比什么都没做更难收拾。
        results = []
        for region in regions:
            text, kind = _format(self.view.substr(region))
            results.append((region, text, kind))

        if all(text == self.view.substr(region) for region, text, _ in results):
            sublime.status_message("Format It: nothing to format")
            return

        # 倒着写回去。前一段变长变短会把后面 region 的偏移全带偏。
        for region, text, _ in reversed(results):
            self.view.replace(edit, region, text)

        # 几段解出来不是同一类就别切语法，标错比不标更碍事。
        kinds = set(kind for _, _, kind in results if kind)
        if len(kinds) == 1:
            self.view.assign_syntax(_SYNTAX[kinds.pop()])


def _format(text):
    """返回 (格式化后的文本, "json" / "sql" / None)。"""
    text = text.strip()
    data = _unwrap(text)
    if data is not _NOT_JSON and not isinstance(data, str):
        return json.dumps(data, indent=2, ensure_ascii=False), "json"

    # 剥到底还是字符串，说明它本来就是被转义过的纯文本（"a\nb\n"）：_unwrap 已经把
    # \n \t 还原成真的换行和缩进，再 dumps 一次等于又 escape 回去。剩下只看它是不是 SQL。
    plain = text if data is _NOT_JSON else data
    if _SQL_HEAD.match(plain):
        formatted = _sql(plain)
        if formatted is not None:
            return formatted, "sql"
    return plain, None


def _unwrap(text):
    data = _peel(text)
    if (data is _NOT_JSON or isinstance(data, str)) \
            and text[:1] in "{[" and text[-1:] in "}]":
        # {\"aaa\": 111} —— 从日志里 copy 出来时外层那对引号常常掉了，补回去再解一次。
        # 只在补完真能解出对象/数组时才认账：给任意括号文本硬套引号，会把里面的
        # \\ \t 一并解掉，那就是在不声不响地改内容了。
        wrapped = _peel('"%s"' % text)
        if wrapped is not _NOT_JSON and not isinstance(wrapped, str):
            return wrapped
    return data


def _peel(text):
    # "{\"aaa\": 111}" 是被当成字符串又编码了一层的形态，解出来还是 str 就继续剥；
    # 剥不动就停在那一层，别让不是 JSON 的字符串把循环卡死。
    data = _loads(text)
    while isinstance(data, str):
        nested = _loads(data)
        if nested is _NOT_JSON:
            break
        data = nested
    return data


def _loads(text):
    try:
        return json.loads(text)
    except ValueError:
        return _NOT_JSON


def _sql(text):
    binary = _pg_format()
    if binary is None:
        sublime.status_message("Format It: pg_format is missing (brew install pgformatter)")
        return None

    # 不传 -X：让 ~/.pg_format 这类 rc 文件继续生效，风格还是调得动的。
    process = subprocess.Popen(
        [binary, "-s", "2", "-L", "-"],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err = process.communicate(text.encode("utf-8"))
    if process.returncode != 0:
        sublime.status_message("Format It: %s" % err.decode("utf-8", "replace").strip())
        return None
    return out.decode("utf-8").rstrip("\n")


def _pg_format():
    # 从 Dock 启动的 Sublime 只继承 /usr/bin:/bin，brew 的目录根本不在 PATH 里，
    # 所以先按固定位置找，找不到才退回 PATH（从终端 subl 起来的那种）。
    for path in ("/opt/homebrew/bin/pg_format", "/usr/local/bin/pg_format"):
        if os.access(path, os.X_OK):
            return path
    return shutil.which("pg_format")

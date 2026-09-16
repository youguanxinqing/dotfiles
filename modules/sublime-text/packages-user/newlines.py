import sublime
import sublime_plugin


def _rewrite(view, edit, convert):
    regions = [r for r in view.sel() if not r.empty()] \
        or [sublime.Region(0, view.size())]
    # 倒着写回去。前一段变长变短会把后面 region 的偏移全带偏。
    for region in reversed(regions):
        view.replace(edit, region, convert(view.substr(region)))


class StripNewlinesCommand(sublime_plugin.TextCommand):
    def run(self, edit):
        # buffer 里的换行一律是 \n：CRLF 是 line_endings 设置，存盘时才变回去。
        _rewrite(self.view, edit, lambda text: text.replace("\n", ""))


class ExpandNewlinesCommand(sublime_plugin.TextCommand):
    def run(self, edit):
        _rewrite(self.view, edit, lambda text: text.replace("\\n", "\n"))

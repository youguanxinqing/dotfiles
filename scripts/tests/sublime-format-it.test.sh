#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=scripts/tests/testlib.sh
source "${DOTFILES_TEST_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)}/scripts/tests/testlib.sh"

PLUGIN="$ROOT/modules/sublime-text/packages-user/format_it.py"
[ -f "$PLUGIN" ] || die "plugin not found: $PLUGIN"

# 插件只能在 Sublime 里 import（sublime / sublime_plugin 是宿主注入的），所以桩掉这两个
# 模块，单独验分派那几层；剩下的都是 view API 调用，没什么可测的。-B 是不让它在仓库里落 pyc。
python3 -B - "$PLUGIN" <<'PY'
import importlib.util
import sys
import types

sublime = types.ModuleType("sublime")
sublime.Region = lambda a, b=0: (a, b)
sublime.status_message = lambda message: None
sublime_plugin = types.ModuleType("sublime_plugin")
sublime_plugin.TextCommand = type("TextCommand", (), {})
sys.modules["sublime"] = sublime
sys.modules["sublime_plugin"] = sublime_plugin

spec = importlib.util.spec_from_file_location("format_it", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
fmt = module._format

JSON_OUT = '{\n  "aaa": 111\n}'

assert fmt('{"aaa": 111}') == (JSON_OUT, "json")
assert fmt('  \n{"aaa": 111}\n  ') == (JSON_OUT, "json")
# 被当字符串又编码了一层的，和外层引号掉了的裸转义串。
assert fmt('"{\\"aaa\\": 111}"') == (JSON_OUT, "json")
assert fmt('{\\"aaa\\": 111}') == (JSON_OUT, "json")
assert fmt('  {\\"aaa\\": 111}  ') == (JSON_OUT, "json")
assert fmt('[\\"a\\", 1]') == ('[\n  "a",\n  1\n]', "json")
# 首尾是括号但补完引号还是解不开的，原样退回去，不能报错也不能改内容。
assert fmt('{foo: bar}') == ('{foo: bar}', None)
assert fmt('{c:\\\\dir}') == ('{c:\\\\dir}', None)
assert fmt('"\\"{\\\\\\"aaa\\\\\\": 111}\\""') == (JSON_OUT, "json")
assert fmt("[1, 2]") == ("[\n  1,\n  2\n]", "json")
# 中文不能被转成 \uXXXX，否则格式化完还是看不懂。
assert fmt('{"a": "\\u4e2d\\u6587"}') == ('{\n  "a": "中文"\n}', "json")

# 转义过的纯文本：还原成真的换行，语法保持不动。
assert fmt('"aaaaa\\nbbbbb\\nccccc\\n"') == ("aaaaa\nbbbbb\nccccc\n", None)
assert fmt('"hello"') == ("hello", None)
# 不是 JSON 也不是 SQL 的东西原样返回，命令那层据此判断"没什么可格式化的"。
assert fmt("not json") == ("not json", None)

assert module._SQL_HEAD.match("  select 1")
assert module._SQL_HEAD.match("WITH t AS (SELECT 1)")
assert not module._SQL_HEAD.match('{"aaa": 111}')
assert not module._SQL_HEAD.match("selected rows")

# pg_format 是模块声明的依赖，但测试要能在还没装依赖的机器上跑过。
if module._pg_format():
    out, kind = fmt("select a,b from t where a=1")
    assert kind == "sql", kind
    assert out.startswith("SELECT\n"), out
    # 转义过的 SQL 串要落到同一条分支上。
    out, kind = fmt('"select a from t"')
    assert (kind, out.startswith("SELECT\n")) == ("sql", True), (kind, out)
else:
    sys.stderr.write("pg_format is missing; skipped the SQL branch.\n")
PY

echo "sublime format-it checks passed."

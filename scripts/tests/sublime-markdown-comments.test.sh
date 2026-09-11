#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=scripts/tests/testlib.sh
source "${DOTFILES_TEST_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)}/scripts/tests/testlib.sh"
new_test_root

USER_DIR="$ROOT/modules/sublime-text/packages-user"
PLUGIN="$USER_DIR/markdown_comments.py"
[ -f "$PLUGIN" ] || die "plugin not found: $PLUGIN"

# 装一个假 app bundle，验路径查找那层；这台机器上装没装 MDComments 都不影响结果。
TEST_HOME="$TEST_ROOT/home"
APP_BIN="$TEST_HOME/Applications/MDComments.app/Contents/MacOS/MDComments"
mkdir -p "$(dirname "$APP_BIN")"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$APP_BIN"
chmod +x "$APP_BIN"

HOME="$TEST_HOME" python3 -B - "$PLUGIN" "$USER_DIR/Default.sublime-commands" <<'PY'
import importlib.util
import os
import re
import sys
import types

sublime = types.ModuleType("sublime")
sublime.status_message = lambda message: None
sublime_plugin = types.ModuleType("sublime_plugin")
sublime_plugin.TextCommand = type("TextCommand", (), {})
sys.modules["sublime"] = sublime
sys.modules["sublime_plugin"] = sublime_plugin

spec = importlib.util.spec_from_file_location("markdown_comments", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

# .sublime-commands 里的 command 名字打错了，面板里只是这条不出现，哪儿都不报错。
# Sublime 从类名推命令名：去掉 Command 后缀再转下划线。
name = re.sub(r"(?<!^)([A-Z])", r"_\1",
              module.MarkdownCommentsCommand.__name__[:-len("Command")]).lower()
assert name == "markdown_comments", name
with open(sys.argv[2]) as handle:
    assert '"command": "%s"' % name in handle.read(), "palette entry is missing %s" % name

command = module.MarkdownCommentsCommand()
command.view = types.SimpleNamespace(file_name=lambda: None)
assert not command.is_enabled()
command.view = types.SimpleNamespace(file_name=lambda: "/tmp/a.md")
assert command.is_enabled()

# app bundle 优先于 PATH：那条软链不一定存在，bundle 里的文件一定在。
found = module._mdc()
assert found == os.path.expanduser("~/Applications/" + module._APP_RELATIVE), found
PY

echo "sublime markdown-comments checks passed."

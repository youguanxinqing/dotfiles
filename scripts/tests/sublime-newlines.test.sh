#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=scripts/tests/testlib.sh
source "${DOTFILES_TEST_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)}/scripts/tests/testlib.sh"

USER_DIR="$ROOT/modules/sublime-text/packages-user"
PLUGIN="$USER_DIR/newlines.py"
[ -f "$PLUGIN" ] || die "plugin not found: $PLUGIN"

python3 -B - "$PLUGIN" "$USER_DIR/Default.sublime-commands" <<'PY'
import importlib.util
import re
import sys
import types

sys.modules["sublime"] = types.ModuleType("sublime")
sublime_plugin = types.ModuleType("sublime_plugin")
sublime_plugin.TextCommand = type("TextCommand", (), {})
sys.modules["sublime_plugin"] = sublime_plugin

spec = importlib.util.spec_from_file_location("newlines", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

# .sublime-commands 里的 command 名字打错了，面板里只是这条不出现，哪儿都不报错。
with open(sys.argv[2]) as handle:
    palette = handle.read()
for cls in (module.StripNewlinesCommand, module.SplitByNewlineCommand):
    name = re.sub(r"(?<!^)([A-Z])", r"_\1", cls.__name__[:-len("Command")]).lower()
    assert '"command": "%s"' % name in palette, "palette entry is missing %s" % name

cases = [
    ("a\\nb", "a\nb"),
    ("a\\\\nb", "a\nb"),
    ("a\\\\\\nb", "a\nb"),
    ("a\\r\\nb", "a\nb"),
    ("a\\\\r\\\\nb", "a\nb"),
    # 单独的 \r、不跟 n 的反斜杠都不是换行，原样留着。
    ("a\\rb\\tc", "a\\rb\\tc"),
    ("a\nb", "a\nb"),
]
for given, want in cases:
    got = module._split(given)
    assert got == want, "%r -> %r, want %r" % (given, got, want)
PY

echo "sublime newlines checks passed."

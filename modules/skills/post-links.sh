#!/usr/bin/env bash

set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)"

# Claude Code reads only ~/.claude/skills and has no setting to add a path
# (anthropics/claude-code#31005), so its view of the skill root has to be
# rebuilt after every install. Run the repo copy: on a fresh machine
# ~/.local/bin is linked but not necessarily on PATH yet.
# Third-party skills first, so the mirror below sees them. Installs only what
# remote.txt declares and ~/.agents/skills lacks; a no-op on a synced machine.
"$ROOT/bin/skills-restore"
exec "$ROOT/bin/skills-mirror"

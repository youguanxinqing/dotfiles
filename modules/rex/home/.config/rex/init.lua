-- pane.zoom toggles: zoom in if not zoomed, restore if zoomed
rex.bind("ctrl+b>z", "pane.zoom")

-- ctrl+b now starts a sequence; press it twice to send one ctrl+b to the terminal
rex.bind("ctrl+b>ctrl+b", "pane.send_key", { key = "ctrl+b" })

-- tmux muscle memory. Bindings match unshifted keys, so % is shift+5 and " is shift+'.
rex.bind("ctrl+b>shift+5", "pane.split.right")
rex.bind("ctrl+b>shift+'", "pane.split.down")
-- herdr's defaults: prefix+v splits side by side, prefix+minus top and bottom.
-- (prefix+h stays focus-left, as in herdr.)
rex.bind("ctrl+b>v", "pane.split.right")
rex.bind("ctrl+b>-", "pane.split.down")
rex.bind("ctrl+b>x", "pane.close")
-- herdr's prefix+N, but asking for the name first: the session picker's
-- "Filter or create..." field creates a session from a name that matches none.
rex.bind("ctrl+b>shift+n", "session.switch")

-- herdr's prefix+T. An unnamed tab shows its focused pane's title; a renamed one
-- keeps its name. Renaming to empty goes back to following the pane.
rex.bind("ctrl+b>shift+t", "client.tab.rename")

-- Move between panes in this tab, vim-style (herdr's prefix+hjkl). Stops at the edge.
rex.bind("ctrl+b>h", "pane.focus.left")
rex.bind("ctrl+b>j", "pane.focus.down")
rex.bind("ctrl+b>k", "pane.focus.up")
rex.bind("ctrl+b>l", "pane.focus.right")

-- ctrl+b f: fuzzy-jump to any tab in any session (herdr's prefix+f). Rex has no
-- tab picker, so fzf runs in a floating pane. Rex 0.1.0 (1696) facts that shape it:
-- * run must return at once. The app holds back every later key until a key's
--   action returns, so waiting for the pick inside run deadlocks the picker.
-- * The app ignores server-side focus (`rex window focus` moves the server's
--   active window, not the view), so the picker must switch through the client
--   action session.select -- from the CLI, which needs Remote Control on.
-- * The tab list is built by the picker, on the pane's own host, with
--   `rex do -e`. In a pane on another host the action itself runs here on the
--   Mac (see remote_image_paste), and each of its calls there is a round trip
--   through the app; listing tabs from here took one per tab, and was slow.
--   The picker reaches the app through app_client.
local terminal = "com.superlogical.terminal"

-- The pane's last reported cwd, from its file:// URL.
local function pwd_of(q)
  local url = (rex.block.call(terminal, "pwd", q) or {}).pwd or ""
  return (url:gsub("^file://[^/]*", ""):gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end

-- The window the key came from: the one on screen, which the server's
-- active window may not be.
local function window_of(ctx)
  return assert(rex.session.describe_block{ block_id = ctx.block_id }).block.window_id
end

-- Every floating pane's script starts with this. The pane runs on the key's
-- pane's host, so PATH has to find rex, fzf and bash on the Mac and on NixOS
-- (which has no /bin/bash; tools live in per-user profiles).
local SH_PATH = [[
export PATH="$REX_BIN_DIR:$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/etc/profiles/per-user/$USER/bin:$HOME/.nix-profile/bin:/run/current-system/sw/bin:$PATH"
]]

-- The app, for `rex -C` in a floating pane on the pane's host. In a remote pane
-- ctx.client_id is the Mac server's ID, which that host doesn't know, so the
-- app's label stands in. rex.exec runs here on the Mac, so its rex talks to
-- the Mac's server; a key's action gets neither REX_BIN_DIR nor HOME (only
-- `rex do` passes them), so fall back to where the app installs the server.
local function app_client(ctx)
  if not ctx.server then return ctx.client_id or "" end
  local r = rex.exec{ "/bin/sh", "-c", [[
    export HOME=${HOME:-$2}
    bin=${REX_BIN_DIR:-"$HOME/Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/Rex Server.app/Contents/MacOS"}
    "$bin/rex" client inspect "$1" | sed -n 's/^label: *//p']], "sh", ctx.client_id or "", os.getenv("HOME") }
  local label = r.ok and r.stdout:gsub("%s+$", "") or ""
  assert(label ~= "", "no label for app client " .. tostring(ctx.client_id) .. ": " .. r.stderr)
  return label
end

-- Whether a tab was given a name, rather than keeping the default label made
-- from its ID ("Window 8762a745").
local function is_named(w)
  return w.label ~= "Window " .. w.window_id:sub(-8)
end

-- A renamed tab shows its name. An unnamed one keeps the default label made from
-- its ID ("Window 8762a745") and shows its focused pane's title instead.
-- Prints one row per tab; CURRENT is replaced by the window the key came from.
local TAB_ROWS = [==[
local terminal, current, home = "com.superlogical.terminal", "CURRENT", os.getenv("HOME")
-- A session's windows are readable only on a stream attached to it.
for _, s in ipairs(assert(rex.call("session.attach_all", { event_scope = "session" })).sessions) do
  -- A session with no windows comes back without a windows field at all.
  local view = rex.session.view{ session_id = s.session_id } or {}
  for i, w in ipairs(view.windows or {}) do
    local q = { session_id = s.session_id, block_id = w.focused_block_id }
    local title = w.label ~= "Window " .. w.window_id:sub(-8) and w.label
      or (rex.block.call(terminal, "title", q) or {}).title or ""
    local url = (rex.block.call(terminal, "pwd", q) or {}).pwd or ""
    local pwd = url:gsub("^file://[^/]*", ""):gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
    if pwd:sub(1, #home) == home then pwd = "~" .. pwd:sub(#home + 1) end
    print(table.concat({
      s.session_id, w.window_id, (w.window_id == current and "*" or " ") .. i, s.label or "", title, pwd,
    }, "\t"))
  end
end
]==]

-- When a focused pane closes or is detached, Rex focuses some other block in its
-- window -- the newest, not the one focused before. So each floating prompt
-- below hands focus back to the pane it came from ($3) before it exits.
--
-- Fields 1-2 are the IDs: hidden from fzf, then cut back out of its pick.
-- A failed select (Remote Control off) keeps its error on screen until Enter.
local picker = SH_PATH .. [[
pick=$(rex do -e "$1" | fzf --delimiter='\t' --with-nth=3.. --layout=reverse --prompt='tab> ')
rex focus "$3" 2>/dev/null
[ -n "$pick" ] || exit 0
s=$(printf '%s\n' "$pick" | cut -f1)
w=$(printf '%s\n' "$pick" | cut -f2)
rex -C "$2" do session.select session_id="$s" window_id="$w" || read -r _
]]

rex.action{
  name  = "tab_jump",
  title = "Jump to Tab…",
  run   = function(ctx)
    local here, client = window_of(ctx), app_client(ctx)
    assert(rex.session.new_layer{
      window_id = here,
      bounds    = { 0.2, 0.15, 0.6, 0.5 },
      focus     = true,
      layout    = rex.layout.block{
        flavor  = "com.superlogical.terminal.shell",
        options = { shell = "none", command = {
          "/bin/sh", "-c", picker, "sh", (TAB_ROWS:gsub("CURRENT", here)), client, ctx.block_id,
        } },
      },
    })
  end,
}
rex.bind("ctrl+b>f", "tab_jump")

-- ctrl+b p / ctrl+b q: a scratch shell per session (herdr's prefix+p / prefix+q).
-- p floats it over this tab, starting it in the current pane's directory the
-- first time; q inside it hides it. Hiding detaches the block, so the shell and its
-- scrollback keep running outside every window until p brings them back. It
-- belongs to the session: another session gets its own, and closing the session
-- closes it. exit or ctrl+b x ends it for good.
local SCRATCH = "scratch" -- block label: how a session finds its scratch again
local SCRATCH_BOUNDS = { 0.15, 0.1, 0.7, 0.7 }

local function scratch_of(session_id)
  for _, b in ipairs(assert(rex.session.list_blocks{ session_id = session_id }).blocks) do
    if b.label == SCRATCH then return b end
  end
end

-- session -> the pane focused when p brought the scratch up, for q to hand
-- focus back to. Lost on config reload; q then leaves focus where Rex puts it.
local scratch_return = {}

local function hide_scratch(ctx)
  local b = scratch_of(ctx.session_id)
  if b and b.placement == "placed" then
    assert(rex.session.detach_block{ block_id = b.block_id })
    local back = scratch_return[ctx.session_id]
    local d = back and rex.session.describe_block{ block_id = back }
    if d and d.block.window_id == b.window_id then
      assert(rex.session.focus_block{ block_id = back })
    end
  end
end

local function show_scratch(ctx)
  scratch_return[ctx.session_id] = ctx.block_id
  local b = scratch_of(ctx.session_id)
  if not b then
    local pwd = pwd_of({ block_id = ctx.block_id })
    local made = assert(rex.session.new_layer{
      window_id = window_of(ctx),
      bounds    = SCRATCH_BOUNDS,
      focus     = true,
      layout    = rex.layout.block{
        flavor  = "com.superlogical.terminal.shell",
        options = { cwd = pwd ~= "" and pwd or nil },
      },
    })
    assert(rex.session.set_block_label{ block_id = made.block_ids[1], label = SCRATCH })
    return
  end
  -- A layout only ever starts new blocks, so an existing one comes back in two
  -- steps: move_block places it (detached or in another tab) as a split here,
  -- then float_block lifts it into a floating layer.
  assert(rex.session.move_block{ block_id = b.block_id, anchor_block_id = ctx.block_id })
  assert(rex.session.float_block{ block_id = b.block_id, bounds = SCRATCH_BOUNDS })
  assert(rex.session.focus_block{ block_id = b.block_id })
end

rex.action{
  name  = "scratch_toggle",
  title = "Toggle Scratch Shell",
  run   = function(ctx)
    local b = scratch_of(ctx.session_id)
    if b and b.placement == "placed" and b.window_id == window_of(ctx) then
      hide_scratch(ctx)
    else
      show_scratch(ctx)
    end
  end,
}
rex.bind("ctrl+b>p", "scratch_toggle")

-- ctrl+b q outside the scratch: tmux's display-panes (herdr-hop in herdr). Each
-- pane in this tab gets a big number; pressing it focuses that pane, any other
-- key or 20 s (display-panes-time in tmux.conf) stays put. The numbers are
-- small floating terminals: Rex draws nothing over a pane itself. The one over
-- the current pane is red, like tmux, and is the one that reads the key.
local DIGITS = {
  { " # ", "## ", " # ", " # ", "###" }, { "###", "  #", "###", "#  ", "###" },
  { "###", "  #", "###", "  #", "###" }, { "# #", "# #", "###", "  #", "  #" },
  { "###", "#  ", "###", "  #", "###" }, { "###", "#  ", "###", "# #", "###" },
  { "###", "  #", "  #", "  #", "  #" }, { "###", "# #", "###", "# #", "###" },
  { "###", "# #", "###", "  #", "###" },
}

local function big(n)
  local rows = {}
  for i, row in ipairs(DIGITS[n]) do rows[i] = (row:gsub(" ", "  "):gsub("#", "██")) end
  return table.concat(rows, "\n")
end

-- Tiled panes in layout order: left to right, top to bottom.
local function tiled(node, out)
  if node.block_id then
    out[#out + 1] = node
  else
    tiled(node.split.before, out)
    tiled(node.split.after, out)
  end
  return out
end

-- $1 digit art, $2 its SGR colour. The reader also gets $3 the pane to fall
-- back to, $4 the panes in number order, $5 the other number floats to close.
-- A new float starts at 80x24 and the app shrinks it to its bounds a moment
-- later; art centred for 80x24 lands off screen until redrawn. So the first
-- frame assumes the 9x14 the bounds aim at, and WINCH redraws for the real
-- size. bash runs the trap while read waits (zsh does not), so even floats that
-- never get a key wait in read -- with the default IFS, which the trap's word
-- splitting runs under.
local hop = [[
art=$1 sgr=$2 orig=$3 panes=$4 others=$5
draw() {
  printf '\033[?25l\033[2J\033[%d;1H\033[%sm' $((($1 - 5) / 2 + 1)) "$sgr"
  printf '%s\n' "$art" | while IFS= read -r l; do printf '%*s%s\n' $((($2 - 6) / 2)) '' "$l"; done
}
trap 'draw $(stty size)' WINCH
size=$(stty size)
if [ "$size" = "24 80" ]; then draw 9 14; else draw $size; fi
read -rsn1 -t 20 k
[ -n "$orig" ] || exit 0
set -- $panes
target=$orig
case $k in [1-9]) [ "$k" -le $# ] && eval "target=\${$k}" ;; esac
rex focus "$target" 2>/dev/null
rex block close $others 2>/dev/null
]]

local function pane_hop(ctx)
  local here, win = window_of(ctx), nil
  for _, w in ipairs(assert(rex.session.view{}).windows) do
    if w.window_id == here then win = w end
  end
  if win.zoomed_block_id then return end -- one pane on screen, nowhere to hop
  local panes = {}
  for _, l in ipairs(win.layers) do
    if l.kind == "tiled" then panes = tiled(l.layout, {}) end
  end
  -- ponytail: one keypress picks, so 9 at most, as in tmux; a 10th pane gets no number.
  while #panes > 9 do table.remove(panes) end

  -- Float size in window fractions, for about 14x9 cells.
  local first = panes[1]
  local size = rex.block.call(terminal, "size", { block_id = first.block_id }) or {}
  local w = math.min(14 * first.rect[3] / (size.columns or 80), 1)
  local h = math.min(9 * first.rect[4] / (size.rows or 24), 1)
  local function float(p, n, focus, extra)
    local r = p.rect
    local cmd = { "/bin/sh", "-c", SH_PATH .. 'exec bash -c "$@"', "sh", hop, "hop", big(n), focus and "1;31" or "1;34" }
    for _, a in ipairs(extra or {}) do cmd[#cmd + 1] = a end
    return assert(rex.session.new_layer{
      window_id = here,
      bounds    = { r[1] + (r[3] - w) / 2, r[2] + (r[4] - h) / 2, w, h },
      focus     = focus,
      layout    = rex.layout.block{
        flavor  = "com.superlogical.terminal.shell",
        options = { shell = "none", command = cmd },
      },
    }).block_ids[1]
  end

  local reader, ids, others = #panes, {}, {}
  for i, p in ipairs(panes) do
    ids[i] = p.block_id
    if p.block_id == ctx.block_id then reader = i end
  end
  for i, p in ipairs(panes) do
    if i ~= reader then others[#others + 1] = float(p, i, false) end
  end
  float(panes[reader], reader, true, { ctx.block_id, table.concat(ids, " "), table.concat(others, " ") })
end

-- herdr splits prefix+q the same way: inside the scratch it hides it.
rex.action{
  name  = "scratch_hide_or_hop",
  title = "Hide Scratch / Number Panes",
  run   = function(ctx)
    local b = scratch_of(ctx.session_id)
    if b and b.block_id == ctx.block_id then return hide_scratch(ctx) end
    pane_hop(ctx)
  end,
}
rex.bind("ctrl+b>q", "scratch_hide_or_hop")

-- ctrl+b s: flash over the pane's visible text (herdr's prefix+s): type to
-- narrow, a label lands the cursor, v/hjkl/wbe/t/f select, y copies over OSC 52,
-- which Rex hands to the Mac's clipboard. rex-flash (github.com/youguanxinqing/
-- rex-flash, installed by modules/rex/install.sh) is herdr-flash's picker run in a float laid exactly over the pane, at its size in
-- cells, so its frame lines up with the text it captured. The float runs on the
-- pane's host, so rex-flash must be installed there too (~/.local/bin). The
-- capture happens there too: the block's format method returns the whole
-- scrollback, which is megabytes over Tailscale for a long-running shell.
local flash = SH_PATH .. [[
if command -v rex-flash >/dev/null; then
  rex-flash --block "$1" --cols "$2" --rows "$3" ${4:+--screen "$4"} || read -r _
else
  echo "rex-flash is not installed on this host"; read -r _
fi
rex focus "$1" 2>/dev/null
]]

-- The last n rows of a vt capture: the screen, without the scrollback before
-- it. vt separates rows with \r\n and doesn't end the last one; unlike text, it
-- keeps the blank rows at the bottom of the screen.
local function last_rows(text, n)
  local nl = {}
  for i in text:gmatch("()\n") do nl[#nl + 1] = i end
  local cut = nl[#nl - n + 1]
  return cut and text:sub(cut + 1) or text
end

-- Where a block sits in its window, in window fractions. A zoomed block fills
-- the window; a floating layer's layout is relative to the layer's bounds.
local function block_bounds(win, block_id)
  if win.zoomed_block_id == block_id then return { 0, 0, 1, 1 } end
  for _, l in ipairs(win.layers) do
    for _, p in ipairs(tiled(l.layout, {})) do
      if p.block_id == block_id then
        local b, r = l.bounds, p.rect
        return { b[1] + r[1] * b[3], b[2] + r[2] * b[4], r[3] * b[3], r[4] * b[4] }
      end
    end
  end
end

rex.action{
  name  = "flash",
  title = "Flash: Search Visible Text…",
  run   = function(ctx)
    local here, win = window_of(ctx), nil
    for _, w in ipairs(assert(rex.session.view{}).windows) do
      if w.window_id == here then win = w end
    end
    local bounds = assert(win and block_bounds(win, ctx.block_id), "flash: pane not on screen")
    local size = assert(rex.block.call(terminal, "size", { block_id = ctx.block_id }))
    -- A local block's text is an in-process call away, so the picker can paint
    -- the moment its float starts instead of after a 20-40 ms rex capture. A
    -- remote one would send its whole scrollback over Tailscale, so the float
    -- captures it there. Past ~960 KiB format fails, and the float captures too.
    local screen = ""
    if not ctx.server then
      local f = rex.block.call(terminal, "format", { block_id = ctx.block_id, format = "vt" })
      if f and f.content and not f.id then screen = last_rows(f.content, size.rows) end
    end
    assert(rex.session.new_layer{
      window_id = here,
      bounds    = bounds,
      focus     = true,
      layout    = rex.layout.block{
        flavor  = "com.superlogical.terminal.shell",
        -- Started at the pane's size: a float otherwise starts at 80x24, shows
        -- blank, and waits for the app to resize it before the picker can paint.
        options = { shell = "none", size = { columns = size.columns, rows = size.rows }, command = {
          "/bin/sh", "-c", flash, "sh", ctx.block_id, tostring(size.columns), tostring(size.rows), screen,
        } },
      },
    })
  end,
}
rex.bind("ctrl+b>s", "flash")

-- New tabs, after herdr-smart-tab. Each opens in the current pane's directory
-- and is shown once it is in place.
--   ctrl+b c  at the end, unnamed (tmux c).
--   ctrl+b a  right after this tab, in its group (tmux a). Tabs sharing a base
--             name are numbered in tab order: zsh, zshⅱ, zshⅲ. An unnamed tab
--             has no group, so the new one stays unnamed too.
--   cmd+t     at the end, named first in a floating prompt. Esc cancels; an
--             empty name makes an unnamed tab.
local SUFFIX = { "", "ⅱ", "ⅲ", "ⅳ", "ⅴ", "ⅵ", "ⅶ", "ⅷ", "ⅸ", "ⅹ", "ⅺ", "ⅻ" }

local function group_base(label)
  -- Small roman numerals are U+2170-217F, three bytes each in UTF-8.
  while label:find("\226\133[\176-\191]$") do label = label:sub(1, -4) end
  return (label:gsub("%(%d+%)$", ""))
end

local function renumber_group(base)
  local n = 0
  for _, w in ipairs(assert(rex.session.view{}).windows) do
    if is_named(w) and group_base(w.label) == base then
      n = n + 1
      local want = base .. (SUFFIX[n] or ("(" .. n .. ")"))
      if w.label ~= want then
        assert(rex.session.set_window_label{ window_id = w.window_id, label = want })
      end
    end
  end
end

-- Opens a tab at the end and returns its ID. The caller shows it last.
local function open_tab(ctx, label)
  local cwd = pwd_of({ block_id = ctx.block_id })
  return assert(rex.session.new_window{
    window_label = label,
    layout = rex.layout.block{
      flavor  = "com.superlogical.terminal.shell",
      options = { cwd = cwd ~= "" and cwd or nil },
    },
  }).window_id
end

-- The app ignores the server's active window; only a client action moves it.
local function show_tab(ctx, window_id)
  rex.client.queue("session.select", { session_id = ctx.session_id, window_id = window_id })
end

rex.action{
  name  = "tab_new",
  title = "New Tab at End",
  run   = function(ctx)
    show_tab(ctx, open_tab(ctx))
  end,
}

rex.action{
  name  = "tab_new_after",
  title = "New Tab After This One",
  run   = function(ctx)
    local here, windows = window_of(ctx), assert(rex.session.view{}).windows
    local next_id, base = nil, ""
    for i, w in ipairs(windows) do
      if w.window_id == here then
        next_id = windows[i + 1] and windows[i + 1].window_id
        base = is_named(w) and group_base(w.label) or ""
      end
    end
    local id = open_tab(ctx, base ~= "" and base or nil)
    if next_id then
      assert(rex.session.move_window{ window_id = id, before_window_id = next_id })
    end
    if base ~= "" then renumber_group(base) end
    show_tab(ctx, id)
  end,
}

-- $1: the client to ask, $2: the cwd for the tab, $3: the pane to hand focus
-- back to, $4: the session. fzf exits 130 on Esc.
-- The tab is made here, on the pane's host: the actions in this file exist only
-- on the Mac's server. Showing it goes through the app (Remote Control).
local ask_tab_name = SH_PATH .. [[
name=$(fzf --print-query --layout=reverse --prompt='new tab> ' \
  --header='enter: create (empty = unnamed)   esc: cancel' </dev/null)
cancelled=$?
rex focus "$3" 2>/dev/null
[ $cancelled -eq 130 ] && exit 0
w=$(rex window new -s "$4" --focus=false --json ${2:+-c "$2"} ${name:+"$name"} |
  sed -n 's/.*"window_id": *"\([^"]*\)".*/\1/p' | head -n 1)
[ -n "$w" ] && rex -C "$1" do session.select session_id="$4" window_id="$w" || read -r _
]]

rex.action{
  name  = "tab_new_named",
  title = "New Named Tab…",
  run   = function(ctx)
    assert(rex.session.new_layer{
      window_id = window_of(ctx),
      bounds    = { 0.25, 0.3, 0.5, 0.25 },
      focus     = true,
      layout    = rex.layout.block{
        flavor  = "com.superlogical.terminal.shell",
        options = { shell = "none", command = {
          "/bin/sh", "-c", ask_tab_name, "sh", app_client(ctx), pwd_of({ block_id = ctx.block_id }), ctx.block_id, ctx.session_id,
        } },
      },
    })
  end,
}

rex.bind("ctrl+b>c", "tab_new")
rex.bind("ctrl+b>a", "tab_new_after")
rex.bind("cmd+t", "tab_new_named")

-- Half-page scroll in fullscreen Claude Code. Its Scroll context binds
-- PageUp/PageDown to half a viewport by default, so this needs nothing in
-- ~/.claude/keybindings.json. Rex has no action that scrolls its own scrollback,
-- so other panes just get the key: less/nvim page, fish ignores it.
-- [KeyU] matches the physical key, whatever character Option makes the layout
-- type for it (opt+u is a dead key on US layouts).
rex.bind("ctrl+alt+[KeyU]", "pane.send_key", { key = "pageup" })
rex.bind("ctrl+alt+[KeyD]", "pane.send_key", { key = "pagedown" })

-- ctrl+v in a pane on another host pastes the Mac's clipboard image there
-- (herdr's remote_image_paste). An agent CLI on that host reads its own
-- clipboard, which never holds the Mac's screenshot. Shortcuts follow the home
-- server, so this action runs here on the Mac even for a remote pane: ctx.server
-- names the pane's host, and rex.call goes there through the app. The image goes
-- over ssh and its path is pasted; Claude Code and Codex attach a pasted image
-- path. A local pane, or a clipboard with no image, gets a plain ctrl+v.
local function send_ctrl_v() rex.client.queue("pane.send_key", { key = "ctrl+v" }) end

-- $1: ssh host. Prints the image's path on that host; exits 3 when the
-- clipboard has no image. The Mac temp file's random suffix names the copy.
local push_clipboard_image = [[
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
f=$(mktemp -t rex-clip) || exit 1
trap 'rm -f "$f"' EXIT
pngpaste - >"$f" 2>/dev/null || exit 3
dst=/tmp/rex-clipboard-images/${f##*.}.png
ssh -o BatchMode=yes -o ConnectTimeout=5 "$1" "umask 077 && mkdir -p ${dst%/*} && cat >$dst" <"$f" &&
  printf %s "$dst"
]]

-- Rex host label -> ssh alias, for hosts whose two names differ. A label
-- missing here is used as the ssh host as is (nixos is both). The Air's label
-- comes from its hostname, but ssh only knows it as `air`, whose HostKeyAlias
-- is what known_hosts records.
local ssh_alias = { ["guans-macbook-air"] = "air" }

rex.action{
  name  = "remote_image_paste",
  title = "Paste Clipboard Image",
  run   = function(ctx)
    if not ctx.server then return send_ctrl_v() end
    local host = ssh_alias[ctx.server] or ctx.server
    local r = rex.exec{ "/bin/sh", "-c", push_clipboard_image, "sh", host }
    if r.code == 3 then return send_ctrl_v() end
    assert(r.ok, "remote_image_paste: " .. r.stderr)
    assert(rex.call("block.event", {
      session_id = ctx.session_id,
      block_id   = ctx.block_id,
      event      = { type = "paste", payload = { text = r.stdout } },
    }))
  end,
}
rex.bind("ctrl+v", "remote_image_paste")

-- ctrl+b G: worktree dialog (herdr's prefix+shift+g, herdr-worktree). Rex has no
-- worktree concept, so rex-worktree does it with git: a worktree is a session
-- named like bm names it (repo-branch), worktree-links provisions new ones, and
-- dev.yml's two windows are laid out by hand (bootmux has no Rex backend).
-- The float runs on the pane's host, so rex-worktree must be in ~/.local/bin there.
local worktree = SH_PATH .. [[
if command -v rex-worktree >/dev/null; then
  exec bash "$(command -v rex-worktree)" "$@"
else
  echo "rex-worktree is not installed on this host"; read -r _
fi
]]

rex.action{
  name  = "worktree",
  title = "Worktree: Open or Create…",
  run   = function(ctx)
    local pwd = pwd_of({ block_id = ctx.block_id })
    assert(rex.session.new_layer{
      window_id = window_of(ctx),
      bounds    = { 0.15, 0.2, 0.7, 0.4 },
      focus     = true,
      layout    = rex.layout.block{
        flavor  = "com.superlogical.terminal.shell",
        options = { shell = "none", command = {
          "/bin/sh", "-c", worktree, "sh", app_client(ctx), ctx.block_id, pwd,
        } },
      },
    })
  end,
}
rex.bind("ctrl+b>shift+g", "worktree")

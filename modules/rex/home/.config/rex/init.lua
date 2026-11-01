-- pane.zoom toggles: zoom in if not zoomed, restore if zoomed
rex.bind("ctrl+b>z", "pane.zoom")

-- ctrl+b now starts a sequence; press it twice to send one ctrl+b to the terminal
rex.bind("ctrl+b>ctrl+b", "pane.send_key", { key = "ctrl+b" })

-- tmux muscle memory. Bindings match unshifted keys, so % is shift+5 and " is shift+'.
rex.bind("ctrl+b>shift+5", "pane.split.right")
rex.bind("ctrl+b>shift+'", "pane.split.down")
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
-- tab picker, so fzf runs in a floating pane. Two Rex 0.1.0 (1696) facts shape it:
-- * run must return at once. The app holds back every later key until a key's
--   action returns, so waiting for the pick inside run deadlocks the picker.
-- * The app ignores server-side focus (`rex window focus` moves the server's
--   active window, not the view), so the picker must switch through the client
--   action session.select -- from the CLI, which needs Remote Control on.
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

-- Whether a tab was given a name, rather than keeping the default label made
-- from its ID ("Window 8762a745").
local function is_named(w)
  return w.label ~= "Window " .. w.window_id:sub(-8)
end

-- A renamed tab shows its name. An unnamed one keeps the default label made from
-- its ID ("Window 8762a745") and shows its focused pane's title instead.
local function tab_rows(current)
  local home = os.getenv("HOME")
  local rows = {}
  -- A session's windows are readable only on a stream attached to it. An action
  -- gets a stream of its own, attached to its session alone -- not the app's
  -- connection, which is attached everywhere -- so attach_all here changes
  -- nothing the app relies on.
  for _, s in ipairs(assert(rex.call("session.attach_all", { event_scope = "session" })).sessions) do
    local view = rex.session.view{ session_id = s.session_id } or { windows = {} }
    for i, w in ipairs(view.windows) do
      local q = { session_id = s.session_id, block_id = w.focused_block_id }
      local named = is_named(w)
      local title = named and w.label or (rex.block.call(terminal, "title", q) or {}).title or ""
      local pwd = pwd_of(q)
      if pwd:sub(1, #home) == home then pwd = "~" .. pwd:sub(#home + 1) end
      rows[#rows + 1] = table.concat({
        s.session_id, w.window_id, (w.window_id == current and "*" or " ") .. i, s.label or "", title, pwd,
      }, "\t")
    end
  end
  return rows
end

-- When a focused pane closes or is detached, Rex focuses some other block in its
-- window -- the newest, not the one focused before. So each floating prompt
-- below hands focus back to the pane it came from ($3) before it exits.
--
-- Fields 1-2 are the IDs: hidden from fzf, then cut back out of its pick.
-- A failed select (Remote Control off) keeps its error on screen until Enter.
local picker = [[
export PATH="$REX_BIN_DIR:/opt/homebrew/bin:/usr/local/bin:$PATH"
pick=$(fzf --delimiter='\t' --with-nth=3.. --layout=reverse --prompt='tab> ' <"$1")
rm -f "$1"
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
    local here = window_of(ctx)
    local rows_path = os.tmpname()
    local f = assert(io.open(rows_path, "w"))
    f:write(table.concat(tab_rows(here), "\n"), "\n")
    f:close()
    assert(rex.session.new_layer{
      window_id = here,
      bounds    = { 0.2, 0.15, 0.6, 0.5 },
      focus     = true,
      layout    = rex.layout.block{
        flavor  = "com.superlogical.terminal.shell",
        options = { shell = "none", command = {
          "/bin/sh", "-c", picker, "sh", rows_path, ctx.client_id, ctx.block_id,
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
-- A new float can start at a default size and get its real one a moment
-- later, so the art is redrawn whenever the size changes.
local hop = [[
export PATH="$REX_BIN_DIR:/opt/homebrew/bin:/usr/local/bin:$PATH"
art=$1 sgr=$2 orig=$3 panes=$4 others=$5 size= i=0
draw() {
  [ "$size" = "$(stty size)" ] && return
  size=$(stty size)
  set -- $size
  printf '\033[?25l\033[2J\033[%d;1H\033[%sm' $((($1 - 5) / 2 + 1)) "$sgr"
  printf '%s\n' "$art" | while IFS= read -r l; do printf '%*s%s\n' $((($2 - 6) / 2)) '' "$l"; done
}
while [ $i -lt 20 ]; do
  draw
  if [ -z "$orig" ]; then sleep 1
  elif IFS= read -rsn1 -t 1 k; then break; fi
  i=$((i + 1))
done
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
    local cmd = { "/bin/bash", "-c", hop, "hop", big(n), focus and "1;31" or "1;34" }
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
local function open_tab(ctx, label, cwd)
  cwd = cwd or pwd_of({ block_id = ctx.block_id })
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
  args  = { name = "string?", cwd = "string?" },
  run   = function(ctx, args)
    args = args or {}
    show_tab(ctx, open_tab(ctx, args.name ~= "" and args.name or nil, args.cwd))
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
-- back to. fzf exits 130 on Esc.
-- Creating goes back through the app (Remote Control) so it runs tab_new.
local ask_tab_name = [[
export PATH="$REX_BIN_DIR:/opt/homebrew/bin:/usr/local/bin:$PATH"
name=$(fzf --print-query --layout=reverse --prompt='new tab> ' \
  --header='enter: create (empty = unnamed)   esc: cancel' </dev/null)
cancelled=$?
rex focus "$3" 2>/dev/null
[ $cancelled -eq 130 ] && exit 0
rex -C "$1" do tab_new name="$name" cwd="$2" || read -r _
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
          "/bin/sh", "-c", ask_tab_name, "sh", ctx.client_id or "", pwd_of({ block_id = ctx.block_id }), ctx.block_id,
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

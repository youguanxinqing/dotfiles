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

-- Window labels are generic ("Window 8762a745"); the focused pane's title and
-- cwd are what the tab actually shows.
local function tab_rows(current)
  local home = os.getenv("HOME")
  local rows = {}
  for _, s in ipairs(assert(rex.call("session.list")).sessions) do
    local view = assert(rex.session.view{ session_id = s.session_id })
    for i, w in ipairs(view.windows) do
      local q = { session_id = s.session_id, block_id = w.focused_block_id }
      local title = (rex.block.call(terminal, "title", q) or {}).title or ""
      local pwd = pwd_of(q)
      if pwd:sub(1, #home) == home then pwd = "~" .. pwd:sub(#home + 1) end
      rows[#rows + 1] = table.concat({
        s.session_id, w.window_id, (w.window_id == current and "*" or " ") .. i, s.label or "", title, pwd,
      }, "\t")
    end
  end
  return rows
end

-- Fields 1-2 are the IDs: hidden from fzf, then cut back out of its pick.
-- A failed select (Remote Control off) keeps its error on screen until Enter.
local picker = [[
export PATH="$REX_BIN_DIR:/opt/homebrew/bin:/usr/local/bin:$PATH"
pick=$(fzf --delimiter='\t' --with-nth=3.. --layout=reverse --prompt='tab> ' <"$1")
rm -f "$1"
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
        options = { shell = "none", command = { "/bin/sh", "-c", picker, "sh", rows_path, ctx.client_id } },
      },
    })
  end,
}
rex.bind("ctrl+b>f", "tab_jump")

-- ctrl+b p / ctrl+b q: a scratch shell per session (herdr's prefix+p / prefix+q).
-- p floats it over this tab, starting it in the current pane's directory the
-- first time; q hides it. Hiding detaches the block, so the shell and its
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

local function hide_scratch(ctx)
  local b = scratch_of(ctx.session_id)
  if b and b.placement == "placed" then
    assert(rex.session.detach_block{ block_id = b.block_id })
  end
end

local function show_scratch(ctx)
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
rex.action{ name = "scratch_hide", title = "Hide Scratch Shell", run = hide_scratch }
rex.bind("ctrl+b>p", "scratch_toggle")
rex.bind("ctrl+b>q", "scratch_hide")

-- Half-page scroll in fullscreen Claude Code. Its Scroll context binds
-- PageUp/PageDown to half a viewport by default, so this needs nothing in
-- ~/.claude/keybindings.json. Rex has no action that scrolls its own scrollback,
-- so other panes just get the key: less/nvim page, fish ignores it.
-- [KeyU] matches the physical key, whatever character Option makes the layout
-- type for it (opt+u is a dead key on US layouts).
rex.bind("ctrl+alt+[KeyU]", "pane.send_key", { key = "pageup" })
rex.bind("ctrl+alt+[KeyD]", "pane.send_key", { key = "pagedown" })

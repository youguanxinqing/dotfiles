-- pane.zoom toggles: zoom in if not zoomed, restore if zoomed
rex.bind("ctrl+b>z", "pane.zoom")

-- ctrl+b now starts a sequence; press it twice to send one ctrl+b to the terminal
rex.bind("ctrl+b>ctrl+b", "pane.send_key", { key = "ctrl+b" })

-- tmux muscle memory. Bindings match unshifted keys, so % is shift+5 and " is shift+'.
rex.bind("ctrl+b>shift+5", "pane.split.right")
rex.bind("ctrl+b>shift+'", "pane.split.down")
rex.bind("ctrl+b>x", "pane.close")

-- ctrl+b f: fuzzy-jump to any tab in any session (herdr's prefix+f). Rex has no
-- tab picker, so fzf runs in a floating pane. Two Rex 0.1.0 (1696) facts shape it:
-- * run must return at once. The app holds back every later key until a key's
--   action returns, so waiting for the pick inside run deadlocks the picker.
-- * The app ignores server-side focus (`rex window focus` moves the server's
--   active window, not the view), so the picker must switch through the client
--   action session.select -- from the CLI, which needs Remote Control on.
local terminal = "com.superlogical.terminal"

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
      local pwd = ((rex.block.call(terminal, "pwd", q) or {}).pwd or ""):gsub("^file://[^/]*", "")
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
    -- The window the key came from: the one on screen, which the server's
    -- active window may not be.
    local here = assert(rex.session.describe_block{ block_id = ctx.block_id }).block
    local rows_path = os.tmpname()
    local f = assert(io.open(rows_path, "w"))
    f:write(table.concat(tab_rows(here.window_id), "\n"), "\n")
    f:close()
    assert(rex.session.new_layer{
      window_id = here.window_id,
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

-- Half-page scroll in fullscreen Claude Code. Its Scroll context binds
-- PageUp/PageDown to half a viewport by default, so this needs nothing in
-- ~/.claude/keybindings.json. Rex has no action that scrolls its own scrollback,
-- so other panes just get the key: less/nvim page, fish ignores it.
-- [KeyU] matches the physical key, whatever character Option makes the layout
-- type for it (opt+u is a dead key on US layouts).
rex.bind("ctrl+alt+[KeyU]", "pane.send_key", { key = "pageup" })
rex.bind("ctrl+alt+[KeyD]", "pane.send_key", { key = "pagedown" })

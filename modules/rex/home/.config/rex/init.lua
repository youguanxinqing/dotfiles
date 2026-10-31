-- pane.zoom toggles: zoom in if not zoomed, restore if zoomed
rex.bind("ctrl+b>z", "pane.zoom")

-- ctrl+b now starts a sequence; press it twice to send one ctrl+b to the terminal
rex.bind("ctrl+b>ctrl+b", "pane.send_key", { key = "ctrl+b" })

-- tmux muscle memory. Bindings match unshifted keys, so % is shift+5 and " is shift+'.
rex.bind("ctrl+b>shift+5", "pane.split.right")
rex.bind("ctrl+b>shift+'", "pane.split.down")
rex.bind("ctrl+b>x", "pane.close")

-- ctrl+b f: fuzzy-jump to a tab in this session (herdr's prefix+f). Rex has no
-- tab picker, so fzf runs in a floating pane and focuses the pick itself.
-- run must return at once: the app holds back every later key and click until
-- a key's action returns, so an action that waits for the picker deadlocks --
-- the picker never gets a keystroke (Rex 0.1.0 build 1696, froze the app 2 min).
-- ponytail: this session only. Another session needs the client action
-- session.select, which only a waiting action (the deadlock above) or the CLI
-- with Remote Control on can send.
local terminal = "com.superlogical.terminal"

-- Window labels are generic ("Window 8762a745"); the focused pane's title and
-- cwd are what the tab actually shows.
local function tab_rows(view)
  local home = os.getenv("HOME")
  local rows = {}
  for i, w in ipairs(view.windows) do
    local q = { block_id = w.focused_block_id }
    local title = (rex.block.call(terminal, "title", q) or {}).title or ""
    local pwd = ((rex.block.call(terminal, "pwd", q) or {}).pwd or ""):gsub("^file://[^/]*", "")
    if pwd:sub(1, #home) == home then pwd = "~" .. pwd:sub(#home + 1) end
    local mark = w.window_id == view.active_window_id and "*" or " "
    rows[#rows + 1] = table.concat({ w.window_id, mark .. i, title, pwd }, "\t")
  end
  return rows
end

-- Field 1 is the window ID: hidden from fzf, then cut back out of its pick.
local picker = [[
export PATH="$REX_BIN_DIR:/opt/homebrew/bin:/usr/local/bin:$PATH"
w=$(fzf --delimiter='\t' --with-nth=2.. --layout=reverse --prompt='tab> ' <"$1" | cut -f1)
rm -f "$1"
if [ -n "$w" ]; then rex window focus -s "$2" "$w"; fi
]]

rex.action{
  name  = "tab_jump",
  title = "Jump to Tab…",
  run   = function(ctx)
    local rows_path = os.tmpname()
    local f = assert(io.open(rows_path, "w"))
    f:write(table.concat(tab_rows(assert(rex.session.view{})), "\n"), "\n")
    f:close()
    assert(rex.session.new_layer{
      bounds = { 0.2, 0.15, 0.6, 0.5 },
      focus  = true,
      layout = rex.layout.block{
        flavor  = "com.superlogical.terminal.shell",
        options = { shell = "none", command = { "/bin/sh", "-c", picker, "sh", rows_path, ctx.session_id } },
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

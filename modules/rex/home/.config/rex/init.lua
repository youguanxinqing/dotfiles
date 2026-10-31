-- pane.zoom toggles: zoom in if not zoomed, restore if zoomed
rex.bind("ctrl+b>z", "pane.zoom")

-- ctrl+b now starts a sequence; press it twice to send one ctrl+b to the terminal
rex.bind("ctrl+b>ctrl+b", "pane.send_key", { key = "ctrl+b" })

-- tmux muscle memory. Bindings match unshifted keys, so % is shift+5 and " is shift+'.
rex.bind("ctrl+b>shift+5", "pane.split.right")
rex.bind("ctrl+b>shift+'", "pane.split.down")
rex.bind("ctrl+b>x", "pane.close")

-- ctrl+b f: fuzzy-jump to any tab in any session (herdr's prefix+f). Rex has no
-- tab picker, so fzf runs in a floating pane and hands its pick back through a
-- FIFO. Switching the app's tab is a client action, which a key-triggered action
-- may queue; the same call from the CLI needs Remote Control.
local terminal = "com.superlogical.terminal"

-- Window labels are generic ("Window 8762a745"); the focused pane's title and
-- cwd are what the tab actually shows.
local function tab_rows(ctx)
  local home = os.getenv("HOME")
  local rows = {}
  for _, s in ipairs(assert(rex.call("session.list")).sessions) do
    local view = assert(rex.session.view{ session_id = s.session_id })
    for i, w in ipairs(view.windows) do
      local q = { session_id = s.session_id, block_id = w.focused_block_id }
      local title = (rex.block.call(terminal, "title", q) or {}).title or ""
      local pwd = ((rex.block.call(terminal, "pwd", q) or {}).pwd or ""):gsub("^file://[^/]*", "")
      if pwd:sub(1, #home) == home then pwd = "~" .. pwd:sub(#home + 1) end
      local here = s.session_id == ctx.session_id and w.window_id == view.active_window_id
      rows[#rows + 1] = table.concat({
        s.session_id, w.window_id, (here and "*" or " ") .. i, s.label or "", title, pwd,
      }, "\t")
    end
  end
  return rows
end

-- Fields 1-2 are the IDs: hidden from fzf, then cut back out of its pick.
local picker = [[
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
fzf --delimiter='\t' --with-nth=3.. --layout=reverse --prompt='tab> ' <"$1" | cut -f1,2 >"$2"
]]

rex.action{
  name  = "tab_jump",
  title = "Jump to Tab…",
  run   = function(ctx)
    local rows_path = os.tmpname()
    local fifo = rows_path .. ".pick"
    local f = assert(io.open(rows_path, "w"))
    f:write(table.concat(tab_rows(ctx), "\n"), "\n")
    f:close()
    local mk = rex.exec({ "mkfifo", fifo })
    if not (mk and mk.ok) then os.remove(rows_path); error("mkfifo failed", 0) end

    local layer = assert(rex.session.new_layer{
      bounds = { 0.2, 0.15, 0.6, 0.5 },
      focus  = true,
      layout = rex.layout.block{
        flavor  = "com.superlogical.terminal.shell",
        options = { shell = "none", command = { "/bin/sh", "-c", picker, "sh", rows_path, fifo } },
      },
    })
    -- ponytail: an action gets 30s in total, so the pick must land within 25s;
    -- past that the picker closes. A longer browse needs a rex.on script, which
    -- init.lua can't host.
    local r = rex.exec({ "cat", fifo }, { timeout = 25 })
    os.remove(rows_path)
    os.remove(fifo)
    if not (r and r.ok) then
      rex.session.close_layer{ layer_id = layer.layer_id }
      error("tab picker timed out", 0)
    end
    local sid, wid = r.stdout:match("^(%S+)\t(%S+)")
    if sid then rex.client.queue("session.select", { session_id = sid, window_id = wid }) end
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

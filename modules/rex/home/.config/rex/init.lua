-- pane.zoom toggles: zoom in if not zoomed, restore if zoomed
rex.bind("ctrl+b>z", "pane.zoom")

-- ctrl+b now starts a sequence; press it twice to send one ctrl+b to the terminal
rex.bind("ctrl+b>ctrl+b", "pane.send_key", { key = "ctrl+b" })

-- Half-page scroll in fullscreen Claude Code. Its Scroll context binds
-- PageUp/PageDown to half a viewport by default, so this needs nothing in
-- ~/.claude/keybindings.json. Rex has no action that scrolls its own scrollback,
-- so other panes just get the key: less/nvim page, fish ignores it.
-- [KeyU] matches the physical key, whatever character Option makes the layout
-- type for it (opt+u is a dead key on US layouts).
rex.bind("ctrl+alt+[KeyU]", "pane.send_key", { key = "pageup" })
rex.bind("ctrl+alt+[KeyD]", "pane.send_key", { key = "pagedown" })

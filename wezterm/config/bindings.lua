local wezterm = require("wezterm")

local action = wezterm.action

return {
    leader = { key = 'b', mods = 'CTRL', timeout_milliseconds = 1000 },
    keys = {
        {
            key = '"',
            mods = 'LEADER|SHIFT',
            action = action.SplitVertical { domain = 'CurrentPaneDomain' },
        },
        {
            key = '%',
            mods = 'LEADER|SHIFT',
            action = action.SplitHorizontal { domain = 'CurrentPaneDomain' },
        },
        {
            key = 'z',
            mods = 'LEADER',
            action = action.TogglePaneZoomState,
        },
        {
            key = 'LeftArrow',
            mods = 'LEADER',
            action = action.ActivatePaneDirection 'Left',
        },
        {
            key = 'RightArrow',
            mods = 'LEADER',
            action = action.ActivatePaneDirection 'Right',
        },
        {
            key = 'UpArrow',
            mods = 'LEADER',
            action = action.ActivatePaneDirection 'Up',
        },
        {
            key = 'DownArrow',
            mods = 'LEADER',
            action = action.ActivatePaneDirection 'Down',
        },
        {
            key = 'x',
            mods = 'LEADER|CTRL',
            action = action.CloseCurrentPane { confirm = true },
        },
        {
            key = 'F',
            mods = 'CTRL',
            action = action.Search { Regex = '' },
        },
        {
            key = 'n',
            mods = 'LEADER|CTRL',
            action = action.SpawnCommandInNewTab {
                domain = 'CurrentPaneDomain',
            },
        },
        {
            key = 'c',
            mods = 'LEADER',
            action = action.CloseCurrentTab { confirm = true },
        },
        {
            key = 'LeftArrow',
            mods = 'CTRL|SHIFT',
            action = action.AdjustPaneSize { "Left", 1 },
        },
        {
            key = 'RightArrow',
            mods = 'CTRL|SHIFT',
            action = action.AdjustPaneSize { "Right", 1 },
        },
        {
            key = 'UpArrow',
            mods = 'CTRL|SHIFT',
            action = action.AdjustPaneSize { "Up", 1 },
        },
        {
            key = 'DownArrow',
            mods = 'CTRL|SHIFT',
            action = action.AdjustPaneSize { "Down", 1 },
        },
        { key = 'l', mods = 'ALT', action = wezterm.action.ShowLauncher },
    },
}

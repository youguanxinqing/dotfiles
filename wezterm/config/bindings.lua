local wezterm = require("wezterm")

local action = wezterm.action

wezterm.on("switch-to-left", function(window, pane)
	local tab = window:mux_window():active_tab()

	if tab:get_pane_direction("Left") ~= nil then
		window:perform_action(wezterm.action.ActivatePaneDirection("Left"), pane)
	else
		window:perform_action(wezterm.action.ActivateTabRelative(-1), pane)
	end
end)

wezterm.on("switch-to-right", function(window, pane)
	local tab = window:mux_window():active_tab()

	if tab:get_pane_direction("Right") ~= nil then
		window:perform_action(wezterm.action.ActivatePaneDirection("Right"), pane)
	else
		window:perform_action(wezterm.action.ActivateTabRelative(1), pane)
	end
end)

return {}

-- return {
-- 	leader = { key = "b", mods = "CTRL", timeout_milliseconds = 1000 },
-- 	keys = {
-- 		-- delete default key bindings
-- 		{
-- 			key = "w",
-- 			mods = "CTRL|SHIFT",
-- 			action = "DisableDefaultAssignment",
-- 		},
--
-- 		{
-- 			key = '"',
-- 			mods = "LEADER|SHIFT",
-- 			action = action.SplitVertical({ domain = "CurrentPaneDomain" }),
-- 		},
-- 		{
-- 			key = "%",
-- 			mods = "LEADER|SHIFT",
-- 			action = action.SplitHorizontal({ domain = "CurrentPaneDomain" }),
-- 		},
-- 		{
-- 			key = "z",
-- 			mods = "LEADER",
-- 			action = action.TogglePaneZoomState,
-- 		},
-- 		{
-- 			key = "LeftArrow",
-- 			mods = "LEADER",
-- 			action = action.ActivatePaneDirection("Left"),
-- 		},
-- 		{
-- 			key = "RightArrow",
-- 			mods = "LEADER",
-- 			action = action.ActivatePaneDirection("Right"),
-- 		},
-- 		{
-- 			key = "UpArrow",
-- 			mods = "LEADER",
-- 			action = action.ActivatePaneDirection("Up"),
-- 		},
-- 		{
-- 			key = "DownArrow",
-- 			mods = "LEADER",
-- 			action = action.ActivatePaneDirection("Down"),
-- 		},
-- 		{
-- 			key = "x",
-- 			mods = "LEADER|CTRL",
-- 			action = action.CloseCurrentPane({ confirm = true }),
-- 		},
-- 		{
-- 			key = "F",
-- 			mods = "CTRL",
-- 			action = action.Search({ Regex = "" }),
-- 		},
-- 		{
-- 			key = "n",
-- 			mods = "LEADER|CTRL",
-- 			action = action.SpawnCommandInNewTab({
-- 				domain = "CurrentPaneDomain",
-- 			}),
-- 		},
-- 		{
-- 			key = "c",
-- 			mods = "LEADER",
-- 			action = action.CloseCurrentTab({ confirm = true }),
-- 		},
-- 		{
-- 			key = "LeftArrow",
-- 			mods = "CTRL|SHIFT",
-- 			action = action.AdjustPaneSize({ "Left", 1 }),
-- 		},
-- 		{
-- 			key = "RightArrow",
-- 			mods = "CTRL|SHIFT",
-- 			action = action.AdjustPaneSize({ "Right", 1 }),
-- 		},
-- 		{
-- 			key = "UpArrow",
-- 			mods = "CTRL|SHIFT",
-- 			action = action.AdjustPaneSize({ "Up", 1 }),
-- 		},
-- 		{
-- 			key = "DownArrow",
-- 			mods = "CTRL|SHIFT",
-- 			action = action.AdjustPaneSize({ "Down", 1 }),
-- 		},
-- 		{ key = "l", mods = "ALT", action = wezterm.action.ShowLauncher },
--
-- 		-- workspace
-- 		{
-- 			key = "0",
-- 			mods = "ALT",
-- 			action = action.ShowLauncherArgs({
-- 				flags = "FUZZY|WORKSPACES",
-- 			}),
-- 		},
-- 		-- switch tab
-- 		{
-- 			key = "h",
-- 			mods = "ALT",
-- 			action = wezterm.action.EmitEvent("switch-to-left"),
-- 		},
-- 		{
-- 			key = "l",
-- 			mods = "ALT",
-- 			action = wezterm.action.EmitEvent("switch-to-right"),
-- 		},
-- 		{
-- 			key = "n",
-- 			mods = "ALT",
-- 			action = action.SpawnCommandInNewTab({
-- 				domain = "CurrentPaneDomain",
-- 			}),
-- 		},
-- 	},
-- }

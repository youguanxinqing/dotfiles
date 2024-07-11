local wezterm = require("wezterm")
local colors = require("colors.custom")

return {
	color_scheme = "Atlas (base16)",
	colors = colors,

	-- font settings
	font_size = 17.5,
	-- font = wezterm.font("JetBrainsMono Nerd Font"),
	font = wezterm.font_with_fallback({
		{ family = "LXGW WenKai Mono Screen" },
		-- { family = "LXGW WenKai Mono", weight = "Bold" },
		"JetBrainsMono Nerd Font",
	}),

	-- window settings
	window_background_opacity = 0.9,
	window_padding = {
		left = 0,
		right = 0,
		top = 0,
		bottom = 0,
	},
	enable_scroll_bar = true,

	-- tar settings
	enable_tab_bar = true,
	tab_max_width = 50,
}

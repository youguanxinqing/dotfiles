local wezterm = require("wezterm")
local colors = require("colors.custom")

local _config = {
	color_scheme = "Atlas (base16)",
	colors = colors,

	-- font settings
	font_size = 17,
	font = wezterm.font_with_fallback({
		"LXGW WenKai Mono Screen",
		"JetBrainsMono Nerd Font Mono",
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
	enable_tab_bar = false,
}

return _config

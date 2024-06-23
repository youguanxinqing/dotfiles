local base = require("colors.base")

local colorscheme = {
    tab_bar = {
        active_tab = {
            bg_color = base.green,
            fg_color = base.crust,
        },
        inactive_tab = {
            bg_color = base.yellow,
            fg_color = base.crust,
        },
        inactive_tab_hover = {
            bg_color = "#587d8c",
            fg_color = base.crust,
        },
    },
}

return colorscheme

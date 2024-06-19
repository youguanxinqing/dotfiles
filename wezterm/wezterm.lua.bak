local wezterm = require 'wezterm'

local action = wezterm.action

local wsl_domains = wezterm.default_wsl_domains()

local mocha = {
    rosewater = "#f5e0dc",
    flamingo = "#f2cdcd",
    pink = "#f5c2e7",
    mauve = "#cba6f7",
    red = "#f38ba8",
    maroon = "#eba0ac",
    peach = "#fab387",
    yellow = "#f9e2af",
    green = "#a6e3a1",
    teal = "#94e2d5",
    sky = "#89dceb",
    sapphire = "#74c7ec",
    blue = "#89b4fa",
    lavender = "#b4befe",
    text = "#cdd6f4",
    subtext1 = "#bac2de",
    subtext0 = "#a6adc8",
    overlay2 = "#9399b2",
    overlay1 = "#7f849c",
    overlay0 = "#6c7086",
    surface2 = "#585b70",
    surface1 = "#45475a",
    surface0 = "#313244",
    base = "#1f1f28",
    mantle = "#181825",
    crust = "#11111b",
 }

return {

    -- default_prog = { 'C:\\Program Files\\Git\\bin\\bash.exe' },
    -- font = wezterm.font("JetBrainsMono Nerd Font"),
    -- font = wezterm.font(),
    font_size = 13.0,
    color_scheme = "Atlas (base16)",
    enable_scroll_bar = true,
    -- text_background_opacity = 0.3,
    window_background_opacity = 0.9,
    use_ime = true,
    font = wezterm.font("JetBrainsMono Nerd Font"),
    -- font = wezterm.font_with_fallback {
    --     "Hurmit Nerd Font",
    --     -- "Symbols Nerd Font",
    --     -- "JetBrainsMono Nerd Font",
    -- },
    window_padding = {
        left = 0,
        right = 0,
        top = 0,
        bottom = 0,
    },

    -- tab bar
    -- enable_tab_bar = true,
    -- hide_tab_bar_if_only_one_tab = false,
    -- use_fancy_tab_bar = true,
    -- tab_max_width = 25,
    -- show_tab_index_in_tab_bar = true,
    -- switch_to_last_active_tab_when_closing_tab = true,

    colors = {
        tab_bar = {
            background = "#000000",
            active_tab = {
               bg_color = mocha.maroon,
               fg_color = mocha.crust,
            },
            inactive_tab = {
               bg_color = mocha.surface2,
               fg_color = mocha.text,
            },
            inactive_tab_hover = {
               bg_color = mocha.surface0,
               fg_color = mocha.text,
            },
            new_tab = {
               bg_color = mocha.base,
               fg_color = mocha.text,
            },
            new_tab_hover = {
               bg_color = mocha.mantle,
               fg_color = mocha.text,
               italic = true,
            },
         },
    },

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
            action = action.AdjustPaneSize {"Left", 1},
        },
        {
            key = 'RightArrow',
            mods = 'CTRL|SHIFT',
            action = action.AdjustPaneSize {"Right", 1},
        },
        {
            key = 'UpArrow',
            mods = 'CTRL|SHIFT',
            action = action.AdjustPaneSize {"Up", 1},
        },
        {
            key = 'DownArrow',
            mods = 'CTRL|SHIFT',
            action = action.AdjustPaneSize {"Down", 1},
        },
        { key = 'l', mods = 'ALT', action = wezterm.action.ShowLauncher },
    },

    ssh_domains = {
        {
            name = 'mine',
            remote_address = '192.168.211.134',
            username = 'guan',
            remote_wezterm_path = '/root/Code/wezterm/target/release/wezterm',
            ssh_option = {
                identityfile = 'C:\\Users\\Administrator\\.ssh\\id_rsa.pub',
            }
        },
        {
            name = 'mine.ssh',
            remote_address = '192.168.211.134',
            username = 'guan',
            multiplexing = 'None',
            ssh_option = {
                identityfile = 'C:\\Users\\Administrator\\.ssh\\id_rsa.pub',
            }
        },
        {
            name = 'manjaro',
            remote_address = '192.168.31.199',
            username = 'guan',
            remote_wezterm_path = '/root/Code/wezterm/target/release/wezterm',
            ssh_option = {
                identityfile = 'C:\\Users\\Administrator\\.ssh\\id_rsa.pub',
            }
        },
        {
            name = 'manjaro.ssh',
            remote_address = '192.168.31.199',
            username = 'guan',
            multiplexing = 'None',
            ssh_option = {
                identityfile = 'C:\\Users\\Administrator\\.ssh\\id_rsa.pub',
            }
        },
    },

    -- unix_domains = {
    --     {
    --       name = "wsl",
    --       connect_automatically = true,
    --       serve_command = {"wsl", "wezterm-mux-server", "--daemonize"},
    --     }
    -- }
    -- default_gui_startup_args = { 'connect', 'wsl' }
}
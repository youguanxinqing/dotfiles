local wezterm = require("wezterm")

local function current_os()
    if wezterm.target_triple:find("windows") then
        return "windows"
    elseif wezterm.target_triple:find("apple") then
        return "apple"
    elseif wezterm.target_triple:find("linux") then
        return "linux"
    else
        return "unknown"
    end
end

return {
    current_os = current_os,
}

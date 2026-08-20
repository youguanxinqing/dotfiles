local os_utils = require("utils.os")
local table_utils = require("utils.table")

local function load_options_or_empty(package_path)
    local ok, options = pcall(require, package_path)
    if not ok then
        return {}
    end
    return options
end

local function load_ssh_domains_options()
    local os = os_utils.current_os()
    if os == "windows" then
        return load_options_or_empty("config.private_remote.windows")
    elseif os == "apple" then
        return load_options_or_empty("config.private_remote.apple")
    elseif os == "linux" then
        return load_options_or_empty("config.private_remote.linux")
    else
        return {}
    end
end

-- Private files use this shape:
-- {
--     name = "example",
--     remote_address = "server.example.com",
--     multiplexing = "None",
--     username = "user",
--     ssh_option = {
--         identityfile = "~/.ssh/id_ed25519",
--     },
-- }
local config = {
    ssh_domains = {
    }
}

table_utils.extend(config.ssh_domains, load_ssh_domains_options())

return config

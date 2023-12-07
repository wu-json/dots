local wezterm = require("wezterm")
local keymaps = require("keymaps")
local visuals = require("visuals")

local config = {}

config = wezterm.config_builder()

keymaps.apply_to_config(config)
visuals.apply_to_config(config)

return config

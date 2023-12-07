local wezterm = require("wezterm")
local visuals = require("visuals")
local config = {}

config = wezterm.config_builder()

visuals.apply_to_config(config)

return config

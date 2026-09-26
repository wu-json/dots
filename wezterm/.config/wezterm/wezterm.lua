local wezterm = require("wezterm")
local keymaps = require("keymaps")
local shell = require("shell")
local visuals = require("visuals")

local config = {}

config = wezterm.config_builder()

-- Used by image.nvim for inline Markdown images.
config.enable_kitty_graphics = true

keymaps.apply_to_config(config)
shell.apply_to_config(config)
visuals.apply_to_config(config)

return config

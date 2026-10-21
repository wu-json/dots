local wezterm = require("wezterm")
local keymaps = require("keymaps")
local shell = require("shell")
local visuals = require("visuals")

local config = {}

config = wezterm.config_builder()

-- Used by Snacks image previews in Neovim.
config.enable_kitty_graphics = true

-- CMD+drag moves the window even when an app (Claude Code, nvim) has mouse reporting on.
config.mouse_bindings = {
	{
		event = { Drag = { streak = 1, button = "Left" } },
		mods = "CMD",
		mouse_reporting = true,
		action = wezterm.action.StartWindowDrag,
	},
}

keymaps.apply_to_config(config)
shell.apply_to_config(config)
visuals.apply_to_config(config)

-- Machine-specific settings (ssh_domains, etc.) live in the untracked wezterm.local.lua.
local local_config = wezterm.config_dir .. "/wezterm.local.lua"
if io.open(local_config) then
	dofile(local_config)(config)
end

return config

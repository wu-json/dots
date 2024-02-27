local wezterm = require("wezterm")
local act = wezterm.action

local module = {}

local keymaps = {
	-- close the current pane
	{
		key = "e",
		mods = "CMD",
		action = act.CloseCurrentPane({ confirm = true }),
	},
	-- split pane vertically
	{
		key = "d",
		mods = "CMD",
		action = act.SplitVertical({ domain = "CurrentPaneDomain" }),
	},
	-- split pane horizontally
	{
		key = "f",
		mods = "CMD",
		action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }),
	},
	-- navigate between panes
	{
		key = "j",
		mods = "CMD",
		action = act.ActivatePaneDirection("Left"),
	},
	{
		key = "l",
		mods = "CMD",
		action = act.ActivatePaneDirection("Right"),
	},
	{
		key = "i",
		mods = "CMD",
		action = act.ActivatePaneDirection("Up"),
	},
	{
		key = "k",
		mods = "CMD",
		action = act.ActivatePaneDirection("Down"),
	},
}

function module.apply_to_config(config)
	config.keys = keymaps
end

return module

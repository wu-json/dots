local wezterm = require("wezterm")

local module = {}

local keymaps = {
	{
		key = "w",
		mods = "CMD|SHIFT",
		action = wezterm.action.CloseCurrentPane({ confirm = true }),
	},
	{
		key = "d",
		mods = "CMD",
		action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }),
	},
}

function module.apply_to_config(config)
	config.keys = keymaps
end

return module

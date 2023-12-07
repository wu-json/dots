local wezterm = require("wezterm")

local module = {}

local keymaps = {
	{
		key = "w",
		mods = "CMD|SHIFT",
		action = wezterm.action.CloseCurrentPane({ confirm = true }),
	},
}

function module.apply_to_config(config)
	config.keys = keymaps
end

return module

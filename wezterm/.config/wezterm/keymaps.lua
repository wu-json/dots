local wezterm = require("wezterm")
local act = wezterm.action

local module = {}

local keymaps = {
	-- close the current pane
	{
		key = "w",
		mods = "CMD",
		action = act.CloseCurrentPane({ confirm = true }),
	},
	-- split pane vertically (30% height)
	{
		key = "d",
		mods = "CMD",
		action = act.SplitPane({
			direction = "Down",
			size = { Percent = 30 },
		}),
	},
	-- split pane vertically
	{
		key = "e",
		mods = "CMD",
		action = act.SplitVertical({ domain = "CurrentPaneDomain" }),
	},
	-- split pane horizontally (30% width)
	{
		key = "f",
		mods = "CMD",
		action = act.SplitPane({
			direction = "Right",
			size = { Percent = 30 },
		}),
	},
	-- split pane horizontally
	{
		key = "r",
		mods = "CMD",
		action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }),
	},
	-- navigate between panes
	{
		key = "h",
		mods = "CMD",
		action = act.ActivatePaneDirection("Left"),
	},
	{
		key = "l",
		mods = "CMD",
		action = act.ActivatePaneDirection("Right"),
	},
	{
		key = "k",
		mods = "CMD",
		action = act.ActivatePaneDirection("Up"),
	},
	{
		key = "j",
		mods = "CMD",
		action = act.ActivatePaneDirection("Down"),
	},
	-- adjust pane size
	{
		key = "h",
		mods = "CMD|SHIFT",
		action = act.AdjustPaneSize({ "Left", 1 }),
	},
	{
		key = "l",
		mods = "CMD|SHIFT",
		action = act.AdjustPaneSize({ "Right", 1 }),
	},
	{
		key = "k",
		mods = "CMD|SHIFT",
		action = act.AdjustPaneSize({ "Up", 1 }),
	},
	{
		key = "j",
		mods = "CMD|SHIFT",
		action = act.AdjustPaneSize({ "Down", 1 }),
	},
	{
		key = "w",
		mods = "CMD|SHIFT",
		action = wezterm.action.CloseCurrentTab({ confirm = true }),
	},
	{
		key = "LeftArrow",
		mods = "CMD|SHIFT",
		action = wezterm.action.MoveTabRelative(-1),
	},
	{
		key = "RightArrow",
		mods = "CMD|SHIFT",
		action = wezterm.action.MoveTabRelative(1),
	},
	-- toggle pane zoom
	{
		key = "z",
		mods = "CMD",
		action = act.TogglePaneZoomState,
	},
}

function module.apply_to_config(config)
	config.keys = keymaps
end

return module

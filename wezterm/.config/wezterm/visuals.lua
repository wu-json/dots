local wezterm = require("wezterm")

local module = {}

wezterm.on("format-tab-title", function(tab, tabs, panes, config)
	local title = tab.tab_title
	if not title or title == "" then
		-- Anchor the label to the first pane instead of the focused pane.
		local pane = tab.panes[1]
		title = pane and pane.title or "Tab"
	end
	if config.show_tab_index_in_tab_bar then
		local index = tab.tab_index + (config.tab_and_split_indices_are_zero_based and 0 or 1)
		title = index .. ": " .. title
	end
	return " " .. title .. " "
end)

function module.apply_to_config(config)
	config.color_scheme = "carbonfox"
	config.enable_tab_bar = true
	config.show_new_tab_button_in_tab_bar = false
	config.show_close_tab_button_in_tabs = false
	config.show_tab_index_in_tab_bar = true
	config.tab_bar_at_bottom = false
	config.use_fancy_tab_bar = true
	local palette = wezterm.color.get_builtin_schemes()[config.color_scheme]
	config.window_frame = {
		font = wezterm.font({ family = "JetBrains Mono", weight = "Regular" }),
		font_size = 11.0,
		active_titlebar_bg = palette.background,
		inactive_titlebar_bg = palette.background,
	}
	config.colors = {
		tab_bar = {
			background = palette.background,
			inactive_tab_edge = palette.background,
			active_tab = {
				bg_color = palette.ansi[1],
				fg_color = "#ffffff",
				intensity = "Normal",
			},
			inactive_tab = {
				bg_color = palette.background,
				fg_color = palette.brights[1],
			},
			inactive_tab_hover = {
				bg_color = palette.ansi[1],
				fg_color = palette.foreground,
				italic = false,
			},
			new_tab = {
				bg_color = palette.background,
				fg_color = palette.brights[1],
			},
			new_tab_hover = {
				bg_color = palette.ansi[1],
				fg_color = "#ffffff",
				italic = false,
			},
		},
	}
	config.font = wezterm.font_with_fallback({
		"JetBrains Mono",
		{ family = "Hiragino Sans", assume_emoji_presentation = false },
		{ family = "Hiragino Mincho ProN", assume_emoji_presentation = false },
		"Apple Color Emoji",
	})
	config.font_size = 15.0
	config.hide_tab_bar_if_only_one_tab = true
	config.macos_window_background_blur = 10
	config.max_fps = 120
	config.window_background_opacity = 1
	config.window_decorations = "RESIZE | MACOS_FORCE_DISABLE_SHADOW"
end

return module

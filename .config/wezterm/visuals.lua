local module = {}

function module.apply_to_config(config)
	config.color_schemes = {
		["nier"] = {
			background = "#cdc8b0",
			foreground = "#4f4c43",
			brights = { "#4f4c43", "#4f4c43", "#4f4c43", "#4f4c43", "#4f4c43", "#4f4c43", "#4f4c43", "#4f4c43" },
			ansi = { "#4f4c43", "#4f4c43", "#4f4c43", "#4f4c43", "#4f4c43", "#4f4c43", "#4f4c43", "#4f4c43" },
			cursor_bg = "#686458",
			cursor_fg = "#c7c2aa",
		},
	}

	config.color_scheme = "nier"
	config.enable_tab_bar = false
	config.font_size = 16.0
	config.hide_tab_bar_if_only_one_tab = true
	config.macos_window_background_blur = 10
	config.max_fps = 120
	config.window_background_opacity = 0.95
	config.window_decorations = "RESIZE"
end

return module

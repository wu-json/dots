local module = {}

function module.apply_to_config(config)
	config.color_scheme = "nightfox"
	config.font_size = 16.0
	config.hide_tab_bar_if_only_one_tab = true
	config.macos_window_background_blur = 2
	config.window_background_opacity = 0.92
	config.window_decorations = "RESIZE"
end

return module

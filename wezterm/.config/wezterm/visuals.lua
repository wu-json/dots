local module = {}

function module.apply_to_config(config)
	config.color_scheme = "carbonfox"
	config.enable_tab_bar = false
	config.font_size = 15.0
	config.hide_tab_bar_if_only_one_tab = true
	config.macos_window_background_blur = 10
	config.max_fps = 240
	config.window_background_opacity = 0.98
	config.window_decorations = "RESIZE"
end

return module

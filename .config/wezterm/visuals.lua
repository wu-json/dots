local module = {}

function module.apply_to_config(config)
	config.font_size = 16.0
	config.color_scheme = "Nebula (base16)"
	config.hide_tab_bar_if_only_one_tab = true
	config.window_background_opacity = 0.97
end

return module

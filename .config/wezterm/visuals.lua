local module = {}

function module.apply_to_config(config)
	config.font_size = 16.0
	config.color_scheme = "Tokyo Night"
	config.hide_tab_bar_if_only_one_tab = true
end

return module

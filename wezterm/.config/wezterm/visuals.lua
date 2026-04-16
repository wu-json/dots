local wezterm = require("wezterm")

local module = {}

function module.apply_to_config(config)
	config.color_scheme = "carbonfox"
	config.enable_tab_bar = false
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
	config.window_background_opacity = 0.99
	config.window_decorations = "RESIZE"
end

return module

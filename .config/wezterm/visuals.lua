local module = {}

local desert_sand = "hsl: 48 30 79"
local machine_rust = "hsl: 48 8 38"

local function generate_single_color_array(color)
	local colors = {}
	for i = 1, 8 do
		colors[i] = color
	end
	return colors
end

function module.apply_to_config(config)
	config.color_schemes = {
		["nier"] = {
			background = desert_sand,
			foreground = machine_rust,
			brights = generate_single_color_array(machine_rust),
			ansi = generate_single_color_array(machine_rust),
			cursor_bg = machine_rust,
			cursor_fg = desert_sand,
		},
	}

	config.color_scheme = "nier"
	config.enable_tab_bar = false
	config.font_size = 16.0
	config.hide_tab_bar_if_only_one_tab = true
	config.macos_window_background_blur = 10
	config.max_fps = 120
	config.window_background_opacity = 1.0
	config.window_decorations = "RESIZE"
end

return module

local module = {}

function module.apply_to_config(config)
	config.default_prog = { "/opt/homebrew/bin/fish", "-l" }
end

return module

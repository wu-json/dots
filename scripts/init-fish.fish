#!/usr/bin/env fish

# Add homebrew to PATH
if test (uname) = Darwin
    fish_add_path /opt/homebrew/bin
else
    fish_add_path /home/linuxbrew/.linuxbrew/bin
end

# Add aqua to PATH
fish_add_path (aqua root-dir)/bin
set -Ux AQUA_GLOBAL_CONFIG (git rev-parse --show-toplevel)/aqua/aqua.yaml

# Unset theme and save (I like the monochrome look)
fish_config theme save none

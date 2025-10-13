#!/usr/bin/env fish

fish_add_path (aqua root-dir)/bin
set -Ux AQUA_GLOBAL_CONFIG (git rev-parse --show-toplevel)/aqua/aqua.yaml

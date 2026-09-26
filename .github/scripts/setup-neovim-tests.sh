#!/usr/bin/env bash
set -euo pipefail

install_dir="${1:?Usage: setup-neovim-tests.sh INSTALL_DIR}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
snacks_revision=$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["snacks.nvim"]["commit"])' \
  "$script_dir/../../nvim/.config/nvim/lazy-lock.json")
neovim_version=v0.11.5

download_archive() {
  local url="$1"
  local destination="$2"
  mkdir -p "$destination"
  curl --fail --silent --show-error --location --retry 2 "$url" \
    | tar -xz --strip-components=1 -C "$destination"
}

download_archive \
  "https://github.com/neovim/neovim/releases/download/$neovim_version/nvim-linux-x86_64.tar.gz" \
  "$install_dir/nvim"

download_archive \
  "https://github.com/folke/snacks.nvim/archive/$snacks_revision.tar.gz" \
  "$install_dir/snacks.nvim"

#!/usr/bin/env bash
set -euo pipefail

install_dir="${1:?Usage: setup-link-preview-tests.sh INSTALL_DIR}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
bash "$script_dir/setup-neovim-tests.sh" "$install_dir"
html_revision=73a3947324f6efddf9e17c0ea58d454843590cc02
markdown_revision=f969cd3ae3f9fbd4e43205431d0ae286014c05b5

download_archive() {
  local url="$1"
  local destination="$2"
  mkdir -p "$destination"
  curl --fail --silent --show-error --location --retry 2 "$url" \
    | tar -xz --strip-components=1 -C "$destination"
}

build_parser() {
  local language="$1"
  local source_dir="$2"
  local parser_dir="$install_dir/nvim/share/nvim/runtime/parser"
  mkdir -p "$parser_dir"
  cc -O2 -shared -fPIC -I "$source_dir" \
    "$source_dir/parser.c" "$source_dir/scanner.c" \
    -o "$parser_dir/$language.so"
}

download_archive \
  "https://github.com/tree-sitter/tree-sitter-html/archive/$html_revision.tar.gz" \
  "$install_dir/html"
download_archive \
  "https://github.com/tree-sitter-grammars/tree-sitter-markdown/archive/$markdown_revision.tar.gz" \
  "$install_dir/markdown"

build_parser html "$install_dir/html/src"
build_parser markdown "$install_dir/markdown/tree-sitter-markdown/src"
build_parser markdown_inline "$install_dir/markdown/tree-sitter-markdown-inline/src"

#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source scripts/init.sh
ensure_brew
require_tool just just
exec just --justfile "$ROOT/justfile" "${@:-init}"

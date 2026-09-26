#!/usr/bin/env bash
# Compatible with macOS's Bash 3.2.
set -Eeuo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"
skipped=0
green='' yellow='' blue='' reset=''
if [[ -t 1 && -z "${NO_COLOR+x}" && "${TERM:-dumb}" != dumb ]]; then
  green=$'\033[32m' yellow=$'\033[33m' blue=$'\033[36m' reset=$'\033[0m'
fi
ok() { printf '  %s✓%s %s\n' "$green" "$reset" "$*"; }
warn() { printf '  %s!%s %s\n' "$yellow" "$reset" "$*"; skipped=$((skipped + 1)); }
section() { printf '\n%s%s%s\n' "$blue" "$*" "$reset"; }
fail() { printf '  ✗ %s\n' "$*" >&2; exit 1; }
trap 'printf "  ✗ Setup stopped. Fix the error above, then rerun the same command.\n" >&2' ERR

# Quiet on success, full diagnostics on failure.
run() {
  local label=$1 log
  shift
  printf '  → %s\n' "$label"
  log=$(mktemp)
  if "$@" >"$log" 2>&1; then
    rm -f "$log"
    ok "$label"
  else
    cat "$log" >&2
    rm -f "$log"
    fail "$label failed. Fix the error above and rerun."
  fi
}
need() { command -v "$1" >/dev/null 2>&1 || fail "$1 is required. $2"; }

ensure_brew() {
  local candidate installer shellenv
  if ! command -v brew >/dev/null 2>&1; then
    for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
      if [[ -x "$candidate" ]]; then shellenv=$("$candidate" shellenv bash); eval "$shellenv"; break; fi
    done
  fi
  if ! command -v brew >/dev/null 2>&1; then
    section 'Homebrew'
    need curl 'Install curl, then rerun setup.'
    installer=$(mktemp)
    if ! curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$installer"; then
      rm -f "$installer"
      fail 'Could not download Homebrew. Check your network connection and rerun.'
    fi
    # Keep installer prerequisites and privilege prompts visible.
    if ! /bin/bash "$installer"; then
      rm -f "$installer"
      fail 'Homebrew installation failed. Complete the prerequisites printed above and rerun.'
    fi
    rm -f "$installer"
    for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
      if [[ -x "$candidate" ]]; then shellenv=$("$candidate" shellenv bash); eval "$shellenv"; break; fi
    done
    need brew 'Follow the Homebrew shellenv instructions, then rerun.'
  fi
  shellenv=$(brew shellenv bash)
  eval "$shellenv"
  export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_UPGRADE=1
}
require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    ensure_brew
    run "Install $2 (provides $1)" brew install "$2"
    need "$1" "Homebrew installed $2 but $1 is not on PATH; check brew shellenv."
  fi
}
init_brew() {
  section 'Packages'
  ensure_brew
  if brew bundle check --no-upgrade --file="$ROOT/homebrew/Brewfile" >/dev/null 2>&1; then
    ok 'All Brewfile packages already installed'
  else
    # Casks can prompt for passwords: leave this command attached to the terminal.
    printf '  → Install missing Brewfile packages\n'
    brew bundle install --no-upgrade --file="$ROOT/homebrew/Brewfile"
    ok 'Brewfile packages installed'
  fi
}
link_configs() {
  require_tool stow stow
  local preview
  preview=$(mktemp)
  # Check the entire group before applying links; never overwrite/adopt files.
  if ! stow --dir="$ROOT" --target="$HOME" --simulate --verbose "$@" >"$preview" 2>&1; then
    cat "$preview" >&2
    rm -f "$preview"
    fail 'Dotfile conflicts: move or back up the listed files, then rerun. Existing files were preserved.'
  fi
  if grep -qE '(LINK|UNLINK|MKDIR|RMDIR):' "$preview"; then
    rm -f "$preview"
    run "Link configs ($*)" stow --dir="$ROOT" --target="$HOME" "$@"
  else
    rm -f "$preview"
    ok "Configs already linked ($*)"
  fi
}
init_stow() { section 'Dotfiles'; link_configs fish gh-dash nvim pi wezterm yazi; }
init_gh() {
  section 'GitHub extensions'
  require_tool gh gh
  require_tool git git
  link_configs gh-dash
  if ! gh auth status --hostname github.com >/dev/null 2>&1; then
    warn 'GitHub extensions skipped: run gh auth login, then just init-gh-extensions'
    return
  fi
  local extensions extension
  extensions=$(gh extension list)
  for extension in dlvhdr/gh-dash github/gh-stack; do
    if printf '%s\n' "$extensions" | grep -qE "(^|[[:space:]])${extension}([[:space:]]|$)"; then
      ok "$extension already installed"
    else
      run "Install $extension" gh extension install "$extension"
    fi
  done
}
init_pi() {
  section 'Pi extensions'
  require_tool node node
  require_tool npm node
  # Minimum required by the locked Pi coding-agent dependency.
  if ! node -e 'const [major, minor] = process.versions.node.split(".").map(Number); process.exit(major > 22 || (major === 22 && minor >= 19) ? 0 : 1)'; then
    warn 'Pi extensions skipped: Node >=22.19 is required. Run brew upgrade node (or select a newer runtime with fnm), then just init-pi-extensions'
    return
  fi
  local dir fingerprint stamp
  dir="$ROOT/pi/.pi/agent/extensions"
  stamp="$dir/node_modules/.dots-install"
  fingerprint=$(cat "$dir/package.json" "$dir/package-lock.json" | cksum)
  fingerprint="$fingerprint $(node --version) $(npm --version) $(uname -sm)"
  if [[ -f "$stamp" && "$(cat "$stamp")" == "$fingerprint" ]] && npm ls --prefix "$dir" --depth=0 >/dev/null 2>&1; then
    ok 'Pi dependencies already installed (manifests and runtime unchanged)'
  else
    run 'Install Pi dependencies' npm ci --prefix "$dir" --include=dev --no-audit --no-fund
    printf '%s\n' "$fingerprint" > "$stamp"
  fi
  link_configs pi
}
init_fish() {
  section 'Login shell'
  require_tool fish fish
  local fish_path current_shell username
  fish_path=$(command -v fish)
  username=$(id -un)
  case "$(uname -s)" in
    Darwin)
      need dscl 'Use System Settings to change your login shell.'
      current_shell=$(dscl . -read "/Users/$username" UserShell | awk '{print $2}') ;;
    Linux)
      need getent 'Install getent or change your login shell manually.'
      current_shell=$(getent passwd "$username" | cut -d: -f7) ;;
    *) warn 'Automatic login shell setup is unsupported on this OS'; return ;;
  esac
  [[ -n "$current_shell" ]] || fail 'Could not determine the account login shell.'
  if [[ "$current_shell" == "$fish_path" ]] && grep -qxF "$fish_path" /etc/shells; then
    ok 'Fish is already the registered login shell'
    return
  fi
  if [[ ! -t 0 || "${DOTS_NONINTERACTIVE:-0}" == 1 ]]; then
    warn 'Login shell change skipped: run just init-fish in an interactive terminal'
    return
  fi
  need chsh 'Install chsh or change your login shell through system settings.'
  if ! grep -qxF "$fish_path" /etc/shells; then
    need sudo 'Register the Fish path in /etc/shells as an administrator, then rerun.'
    printf '%s\n' "$fish_path" | sudo tee -a /etc/shells >/dev/null
    ok 'Fish registered in /etc/shells'
  fi
  if [[ "$current_shell" != "$fish_path" ]]; then
    chsh -s "$fish_path"
    ok 'Login shell changed to Fish (takes effect on next login)'
  fi
}
init_insomnia() {
  section 'SwiftBar / Insomnia'
  if [[ "$(uname -s)" != Darwin ]]; then warn 'SwiftBar skipped: macOS only'; return; fi
  ensure_brew
  if ! brew list --cask swiftbar >/dev/null 2>&1; then
    run 'Install SwiftBar' brew install --cask swiftbar
  else
    ok 'SwiftBar already installed'
  fi
  link_configs swiftbar
  local plugins domain plist reload=0
  plugins="$HOME/.config/swiftbar/plugins"
  domain="gui/$(id -u)"
  plist="$HOME/Library/LaunchAgents/com.wu-json.swiftbar-login.plist"
  need defaults 'Run this recipe on macOS.'
  need launchctl 'Run this recipe in a macOS desktop session.'
  if [[ "$(defaults read com.ameba.SwiftBar PluginDirectory 2>/dev/null || true)" != "$plugins" ]]; then
    run 'Set SwiftBar plugin directory' defaults write com.ameba.SwiftBar PluginDirectory -string "$plugins"
    reload=1
  else
    ok 'SwiftBar plugin directory already configured'
  fi
  if ! launchctl print "$domain" >/dev/null 2>&1; then
    warn 'SwiftBar launch skipped: no GUI session; rerun just init-insomnia from the desktop'
    return
  fi
  if ! launchctl print "$domain/com.wu-json.swiftbar-login" >/dev/null 2>&1; then
    run 'Register SwiftBar login agent' launchctl bootstrap "$domain" "$plist"
  else
    ok 'SwiftBar login agent already registered'
  fi
  if [[ "$reload" == 1 ]] && pgrep -x SwiftBar >/dev/null 2>&1; then
    run 'Quit SwiftBar to apply its plugin directory' osascript -e 'tell application "SwiftBar" to quit'
  fi
  if ! pgrep -x SwiftBar >/dev/null 2>&1; then
    run 'Start SwiftBar' open -a SwiftBar
  else
    ok 'SwiftBar already running'
  fi
}
init_obscura() {
  section 'Obscura'
  local version=0.1.8 os arch asset tmp
  if [[ -x "$HOME/.local/bin/obscura" && -x "$HOME/.local/bin/obscura-worker" ]] &&
    [[ "$("$HOME/.local/bin/obscura" --version)" == "obscura $version" ]]; then
    ok "Obscura $version already installed"
    return
  fi
  need curl 'Install curl, then rerun just init-obscura.'
  need tar 'Install tar, then rerun just init-obscura.'
  case "$(uname -s)" in Darwin) os=macos ;; Linux) os=linux ;; *) fail 'Unsupported OS' ;; esac
  case "$(uname -m)" in arm64|aarch64) arch=aarch64 ;; x86_64) arch=x86_64 ;; *) fail 'Unsupported architecture' ;; esac
  asset="obscura-${arch}-${os}.tar.gz"
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  run "Download Obscura $version" curl -fsSL "https://github.com/h4ckf0r0day/obscura/releases/download/v${version}/${asset}" -o "$tmp/obscura.tar.gz"
  tar xzf "$tmp/obscura.tar.gz" -C "$tmp" obscura obscura-worker
  mkdir -p "$HOME/.local/bin"
  run 'Install Obscura binaries' install -m 755 "$tmp/obscura" "$tmp/obscura-worker" "$HOME/.local/bin/"
  rm -rf "$tmp"
  trap - EXIT
}
init_tailscale() {
  section 'Tailscale CLI'
  if [[ "$(uname -s)" != Darwin ]]; then warn 'Tailscale app integration skipped: macOS only'; return; fi
  if [[ ! -x /Applications/Tailscale.app/Contents/MacOS/Tailscale ]]; then
    warn 'Tailscale CLI skipped: install Tailscale.app, then rerun just init-tailscale-cli'
    return
  fi
  require_tool fish fish
  # Leave existing /usr/local/bin executables alone.
  # shellcheck disable=SC2016 # Expanded by Fish, not Bash.
  if fish --no-config -c 'contains -- /Applications/Tailscale.app/Contents/MacOS $fish_user_paths'; then
    ok 'Tailscale app directory already on Fish PATH'
  else
    run 'Add Tailscale app directory to Fish PATH' fish --no-config -c 'fish_add_path -U /Applications/Tailscale.app/Contents/MacOS'
  fi
}
case "${1:-init}" in
  bootstrap) ensure_brew; require_tool just just; exec just --justfile "$ROOT/justfile" init ;;
  init) init_brew; init_stow; init_gh; init_pi; init_fish; init_insomnia ;;
  brew) init_brew ;; stow) init_stow ;; gh) init_gh ;; pi) init_pi ;;
  fish) init_fish ;; insomnia) init_insomnia ;; obscura) init_obscura ;; tailscale) init_tailscale ;;
  *) fail "Unknown setup task: $1" ;;
esac
printf '\n'
if [[ "$skipped" -gt 0 ]]; then
  ok "Setup finished with $skipped skipped step(s); follow the instructions above."
else
  ok 'Setup complete.'
fi

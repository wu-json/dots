brew_prefix := if os() == "macos" { "/opt/homebrew" } else { "/home/linuxbrew/.linuxbrew" }

brew:
  brew bundle install --file=homebrew/Brewfile

init: brew init-gh-extensions init-pi-extensions init-fish init-insomnia
  @echo "✓ Initialization complete!"

init-gh-extensions:
  #!/usr/bin/env bash
  set -euo pipefail
  extensions=$(gh extension list)
  if ! printf '%s\n' "$extensions" | grep -qE '(^|[[:space:]])dlvhdr/gh-dash([[:space:]]|$)'; then
    gh extension install dlvhdr/gh-dash
  fi
  stow -t "$HOME" gh-dash

init-insomnia:
  #!/usr/bin/env bash
  set -euo pipefail
  if [ "$(uname -s)" != Darwin ]; then echo "skip: macOS only"; exit 0; fi
  if ! brew list --cask swiftbar >/dev/null 2>&1; then brew install --cask swiftbar; fi
  stow -t "$HOME" swiftbar
  defaults write com.ameba.SwiftBar PluginDirectory -string "$HOME/.config/swiftbar/plugins"
  pkill -x SwiftBar 2>/dev/null || true
  launchctl bootout "gui/$UID" "$HOME/Library/LaunchAgents/com.wu-json.swiftbar-login.plist" 2>/dev/null || true
  launchctl bootstrap "gui/$UID" "$HOME/Library/LaunchAgents/com.wu-json.swiftbar-login.plist"

init-fish:
  grep -qxF "{{brew_prefix}}/bin/fish" /etc/shells || echo "{{brew_prefix}}/bin/fish" | sudo tee -a /etc/shells
  chsh -s {{brew_prefix}}/bin/fish

init-obscura:
  #!/usr/bin/env bash
  set -euo pipefail
  obscura_version="0.1.8"
  case "$(uname -s)" in
    Darwin) os=macos ;;
    Linux)  os=linux ;;
    *) echo "unsupported OS: $(uname -s)"; exit 1 ;;
  esac
  case "$(uname -m)" in
    arm64|aarch64) arch=aarch64 ;;
    x86_64)        arch=x86_64 ;;
    *) echo "unsupported arch: $(uname -m)"; exit 1 ;;
  esac
  asset="obscura-${arch}-${os}.tar.gz"
  url="https://github.com/h4ckf0r0day/obscura/releases/download/v${obscura_version}/${asset}"
  mkdir -p ~/.local/bin
  tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
  echo "downloading $asset ..."
  curl -fsL "$url" -o "$tmp/o.tar.gz"
  tar xzf "$tmp/o.tar.gz" -C ~/.local/bin obscura obscura-worker
  chmod +x ~/.local/bin/obscura ~/.local/bin/obscura-worker
  # Strip Gatekeeper quarantine on macOS so the binary runs without a prompt.
  [ "$os" = macos ] && xattr -d com.apple.quarantine ~/.local/bin/obscura ~/.local/bin/obscura-worker 2>/dev/null || true
  echo "✓ installed $(~/.local/bin/obscura --version)"

init-pi-extensions: stow
  npm ci --prefix pi/.pi/agent/extensions

init-tailscale-cli:
  #!/usr/bin/env bash
  set -euo pipefail
  if [ "$(uname -s)" != Darwin ]; then echo "skip: macOS only"; exit 0; fi
  if [ ! -x /Applications/Tailscale.app/Contents/MacOS/Tailscale ]; then echo "Tailscale.app not found"; exit 1; fi
  sudo rm -f /usr/local/bin/tailscale
  fish -c 'fish_add_path -U /Applications/Tailscale.app/Contents/MacOS'
  echo "✓ Tailscale MacOS dir added to fish's universal PATH"

stow:
  stow -t ~ fish
  stow -t ~ gh-dash
  stow -t ~ nvim
  stow -t ~ pi
  stow -t ~ wezterm
  stow -t ~ yazi

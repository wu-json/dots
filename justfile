brew_prefix := if os() == "macos" { "/opt/homebrew" } else { "/home/linuxbrew/.linuxbrew" }

# macOS: after bundle, strip quarantine on cursor-cli (merkle-tree NAPI). https://forum.cursor.com/t/cursor-agent-merkle-tree-napi-darwin-arm64-node-not-opened/155056
brew:
  brew bundle install --file=homebrew/Brewfile && \
    if [ "$(uname -s)" = Darwin ] && [ -d "{{brew_prefix}}/Caskroom/cursor-cli" ]; then \
      xattr -rd com.apple.quarantine "{{brew_prefix}}/Caskroom/cursor-cli/"; \
    fi

init-fish:
  grep -qxF "{{brew_prefix}}/bin/fish" /etc/shells || echo "{{brew_prefix}}/bin/fish" | sudo tee -a /etc/shells
  chsh -s {{brew_prefix}}/bin/fish

# macOS: App Store Tailscale ships no CLI launcher and crashes via a plain symlink (bundle-identity check), so install a wrapper script.
init-tailscale-cli:
  #!/usr/bin/env bash
  set -euo pipefail
  if [ "$(uname -s)" != Darwin ]; then echo "skip: macOS only"; exit 0; fi
  if [ ! -x /Applications/Tailscale.app/Contents/MacOS/Tailscale ]; then echo "Tailscale.app not found"; exit 1; fi
  sudo tee /usr/local/bin/tailscale > /dev/null <<'EOF'
  #!/bin/sh
  exec "/Applications/Tailscale.app/Contents/MacOS/Tailscale" "$@"
  EOF
  sudo chmod +x /usr/local/bin/tailscale
  tailscale version

# macOS: Obsidian's installer only appends to .zprofile, so fish misses the CLI. Add the app's MacOS dir to fish's universal PATH.
init-obsidian-cli:
  #!/usr/bin/env bash
  set -euo pipefail
  if [ "$(uname -s)" != Darwin ]; then echo "skip: macOS only"; exit 0; fi
  if [ ! -x /Applications/Obsidian.app/Contents/MacOS/Obsidian ]; then echo "Obsidian.app not found"; exit 1; fi
  sudo rm -f /usr/local/bin/obsidian
  fish -c 'fish_add_path -U /Applications/Obsidian.app/Contents/MacOS'
  echo "✓ Obsidian MacOS dir added to fish's universal PATH"

stow:
  stow -t ~ claude
  # Cursor owns ~/.cursor/cli-config.json (auth/model/etc. state), so skip it.
  stow --ignore='cli-config\.json' -t ~ cursor
  stow -t ~ fish
  stow -t ~ nvim
  stow -t ~ opencode
  stow -t ~ wezterm

init: brew stow init-fish
  @echo "✓ Initialization complete!"

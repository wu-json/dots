brew_prefix := if os() == "macos" { "/opt/homebrew" } else { "/home/linuxbrew/.linuxbrew" }

brew:
  brew bundle install --file=homebrew/Brewfile

init-fish:
  grep -qxF "{{brew_prefix}}/bin/fish" /etc/shells || echo "{{brew_prefix}}/bin/fish" | sudo tee -a /etc/shells
  chsh -s {{brew_prefix}}/bin/fish

# macOS: App Store Tailscale ships no CLI launcher, so add the app's MacOS dir to fish's universal PATH. (Symlinks break Tailscale's bundle-identity check, hence PATH over symlink.)
init-tailscale-cli:
  #!/usr/bin/env bash
  set -euo pipefail
  if [ "$(uname -s)" != Darwin ]; then echo "skip: macOS only"; exit 0; fi
  if [ ! -x /Applications/Tailscale.app/Contents/MacOS/Tailscale ]; then echo "Tailscale.app not found"; exit 1; fi
  sudo rm -f /usr/local/bin/tailscale
  fish -c 'fish_add_path -U /Applications/Tailscale.app/Contents/MacOS'
  echo "✓ Tailscale MacOS dir added to fish's universal PATH"

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
  stow -t ~ pi
  stow -t ~ wezterm
  stow -t ~ yazi

init: brew stow init-fish
  @echo "✓ Initialization complete!"

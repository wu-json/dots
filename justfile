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

stow:
  stow -t ~ claude
  stow -t ~ cursor
  stow -t ~ fish
  stow -t ~ nvim
  stow -t ~ wezterm

init: brew stow init-fish
  @echo "✓ Initialization complete!"

brew_prefix := if os() == "macos" { "/opt/homebrew" } else { "/home/linuxbrew/.linuxbrew" }

brew:
  brew bundle install --file=homebrew/Brewfile

init-fish:
  grep -qxF "{{brew_prefix}}/bin/fish" /etc/shells || echo "{{brew_prefix}}/bin/fish" | sudo tee -a /etc/shells
  chsh -s {{brew_prefix}}/bin/fish
  fish scripts/init-fish.fish

stow:
  stow -t ~ claude
  stow -t ~ fish
  stow -t ~ nvim
  stow -t ~ wezterm

init: brew stow init-fish
  @echo "✓ Initialization complete!"

brew:
  brew bundle install --file=homebrew/Brewfile

init-aqua:
  fish scripts/init-aqua.fish

init-fish:
  grep -qxF "/opt/homebrew/bin/fish" /etc/shells || echo "/opt/homebrew/bin/fish" | sudo tee -a /etc/shells
  chsh -s /opt/homebrew/bin/fish

stow:
  echo placeholder
  stow -t ~ fish
  stow -t ~ nvim
  stow -t ~ wezterm

init: brew stow init-fish init-aqua
  @echo "✓ Initialization complete!"

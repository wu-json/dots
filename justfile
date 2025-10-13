brew:
  brew bundle install --file=homebrew/Brewfile

init-aqua:
  fish_add_path $(aqua root-dir)/bin
  set -Ux AQUA_GLOBAL_CONFIG "$(git rev-parse --show-toplevel)/aqua/aqua.yaml"

init-fish:
  echo "/opt/homebrew/bin/fish" | sudo tee -a /etc/shells
  chsh -s /opt/homebrew/bin/fish

stow:
  echo placeholder
  stow -t ~ fish
  stow -t ~ nvim
  stow -t ~ wezterm

init: brew stow init-fish init-aqua

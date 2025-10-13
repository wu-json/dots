# Dotfiles

## Setup

### Install homebrew packages

```bash
brew bundle install
```

### Set up Fish as default shell

```bash
echo "/opt/homebrew/bin/fish" | sudo tee -a /etc/shells
chsh -s /opt/homebrew/bin/fish
```

### Set up aqua

```bash
brew install aqua
set -Ux AQUA_GLOBAL_CONFIG "$(git rev-parse --show-toplevel)/.aqua/aqua.yaml"
```

### SymLink configs

```bash
ln -s "$(git rev-parse --show-toplevel)/.config/fish" $HOME/.config/fish
ln -s "$(git rev-parse --show-toplevel)/nvim" $HOME/.config/nvim
ln -s "$(git rev-parse --show-toplevel)/wezterm" $HOME/.config/wezterm
```

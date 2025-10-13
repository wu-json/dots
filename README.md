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

### Set up fisher and nvm

```bash
set --universal nvm_default_version jod
```

### Set up aqua

```bash
brew install aqua
set -Ux AQUA_GLOBAL_CONFIG '/Users/jasonwu/GitHub/personal/dotfiles/.aqua/aqua.yaml'
```

### SymLink configs

```bash
ln -s $HOME/GitHub/personal/dotfiles/.config/fish $HOME/.config/fish
ln -s $HOME/GitHub/personal/dotfiles/.config/nvim $HOME/.config/nvim
ln -s $HOME/GitHub/personal/dotfiles/.config/wezterm $HOME/.config/wezterm
```

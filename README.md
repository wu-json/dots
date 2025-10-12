# Dotfiles

## Setup

```bash
```
brew install fish

# set up fish as default shell
echo "/opt/homebrew/bin/fish" | sudo tee -a /etc/shells
chsh -s /opt/homebrew/bin/fish

# get some aqua going
brew install aqua
set -Ux AQUA_GLOBAL_CONFIG '/Users/jasonwu/GitHub/personal/dotfiles/.aqua/aqua.yaml'
```

### SymLink Configs

```bash
ln -s $HOME/GitHub/personal/dotfiles/.config/fish $HOME/.config/fish
ln -s $HOME/GitHub/personal/dotfiles/.config/nvim $HOME/.config/nvim
ln -s $HOME/GitHub/personal/dotfiles/.config/wezterm $HOME/.config/wezterm
```


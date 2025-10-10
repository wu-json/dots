# Dotfiles

## Setup

```bash
brew install lazygit fzf ripgrep fd eza autojump
```

From there, you will need [Fish Shell](https://github.com/fish-shell/fish-shell).

```
brew install fish
brew install fisher

# install fisher plugins
fisher update
fish_add_path /opt/homebrew/bin

# set up fish as default shell
echo "/opt/homebrew/bin/fish" | sudo tee -a /etc/shells
chsh -s /opt/homebrew/bin/fish

# get some aqua going
brew install aqua
set -Ux AQUA_GLOBAL_CONFIG '/Users/jasonwu/GitHub/personal/dotfiles/.aqua/aqua.yaml'
```

[WezTerm](https://wezfurlong.org/wezterm/index.html)

### SymLink Configs

```bash
ln -s $HOME/GitHub/personal/dotfiles/.config/karabiner $HOME/.config/karabiner
ln -s $HOME/GitHub/personal/dotfiles/.config/fish $HOME/.config/fish
ln -s $HOME/GitHub/personal/dotfiles/.config/nvim $HOME/.config/nvim
ln -s $HOME/GitHub/personal/dotfiles/.config/wezterm $HOME/.config/wezterm
```


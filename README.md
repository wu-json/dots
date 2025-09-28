# Dotfiles

These are my dotfiles for my WezTerm + Fish + Neovim (LazyVim) development setup. Feel free to clone or steal.

> I decided to go down the Neovim rabbit-hole early December 2023 after seeing some really pretty setups on YouTube. I gave LunarVim a try in November 2023 very unsuccessfully, but the second time around I chose LazyVim and fell in love.

![Screenshot 2024-08-03 at 3 57 08 PM](https://github.com/user-attachments/assets/eb14b207-4261-4612-8fbe-3f91ea3b4264)

## Setup

### Prerequisites

You will first need to install some prerequisites for LazyVim:

```bash
brew install neovim
brew install lazygit

# for fzf-lua
brew install fzf
brew install ripgrep
brew install fd

# maintained version of exa, which is a modern ls replacement
brew install eza
```

From there, you will need [Fish Shell](https://github.com/fish-shell/fish-shell).

```
brew install fish
brew install fisher

# install fisher plugins
fisher update

# add homebrew to path
fish_add_path /opt/homebrew/bin

# set up fish as default shell
echo "/opt/homebrew/bin/fish" | sudo tee -a /etc/shells
chsh -s /opt/homebrew/bin/fish

set -Ux AQUA_GLOBAL_CONFIG '~/.config/aqua/aqua.yaml'
```

Now it's time to install my terminal of choice: [WezTerm](https://wezfurlong.org/wezterm/index.html).

Finally, you will want to set your Anthropic API key in Fish to be able to use [avante.nvim](https://github.com/yetone/avante.nvim) for a Cursor-like Neovim experience.

```bash
set -Ux ANTHROPIC_API_KEY some-api-key
```

### SymLink Configs

After installing the above prerequisites, you can clone this repo somewhere and then make symbolic links to the directories in `.config` like so:

```bash
ln -s $HOME/GitHub/personal/dotfiles/.config/karabiner $HOME/.config/karabiner
ln -s $HOME/GitHub/personal/dotfiles/.config/fish $HOME/.config/fish
ln -s $HOME/GitHub/personal/dotfiles/.config/nvim $HOME/.config/nvim
ln -s $HOME/GitHub/personal/dotfiles/.config/wezterm $HOME/.config/wezterm
ln -s $HOME/GitHub/personal/dotfiles/.config/aqua $HOME/.config/aqua
```


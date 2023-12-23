# Dotfiles

These are my dotfiles for my WezTerm + Neovim (LazyVim) development setup. This repo also includes some bash aliases I use on a regular basis. Feel free to clone or steal.

> I decided to go down the NeoVim rabbit-hole early December 2023 after seeing some really pretty setups on YouTube. I gave LunarVim a try in November 2023 very unsuccessfully, but the second time around I chose LazyVim and fell in love.

![Screenshot 2023-12-23 at 2 08 10 PM](https://github.com/wu-json/dotfiles/assets/45532884/5db8b27b-a226-4f17-b306-c61671314711)

## Setup

### Prerequisites

You will first need to install some prerequisites for LazyVim:

```bash
brew install neovim
brew install lazygit

# for telescope
brew install ripgrep
brew install fd
```

After installing the above, you will just need [WezTerm](https://wezfurlong.org/wezterm/index.html).

### SymLink Configs

After installing the above prerequisites, you can clone this repo somewhere and then make symbolic links to the directories in `.config` like so:

```bash
ln -s $HOME/github/dotfiles/.config/nvim $HOME/.config/nvim
ln -s $HOME/github/dotfiles/.config/wezterm $HOME/.config/wezterm
```

## What's Included?

- [Markdown Preview](https://github.com/iamcco/markdown-preview.nvim)
  - Allows you to preview markdown files in your browser with `:MarkdownPreview` command.
- [Nightfox Theme](https://github.com/EdenEast/nightfox.nvim)
  - So freaking pretty.

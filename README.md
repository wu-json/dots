# Dots

This is where I tweak config files till 4am like a goblin. It's pretty cozy in here.

![banner](assets/banner.png)

## My Cursed Tools

- **[claude](https://code.claude.com/)**
- **[fish](https://fishshell.com/)**
- **[gh-dash](https://www.gh-dash.dev/)**
- **[homebrew](https://brew.sh/)**
- **[neovim](https://neovim.io/)**
- **[pi](https://github.com/badlogic/pi-mono)**
- **[wezterm](https://wezterm.org/index.html)**
- **[stow](https://www.gnu.org/software/stow/)**
- **[SwiftBar](https://github.com/swiftbar/SwiftBar)**
- **[yazi](https://yazi-rs.github.io/)**

## Setup

```bash
bash scripts/bootstrap.sh
```

## Markdown images in Neovim

[image.nvim](https://github.com/3rd/image.nvim) displays images inline in Markdown
buffers, including the banner above, without moving the cursor onto the image.
It reserves space for the image and updates it as you scroll.

Run `just bootstrap brew` to install ImageMagick, reload your WezTerm configuration,
then restart Neovim and let Lazy install image.nvim. Images use WezTerm's Sixel
support; Snacks' image module is disabled to avoid competing renderers.

Sixel redraws the image scene rather than relying on Kitty placements, which left
image strips behind text when scrolling in WezTerm. This is a mitigation pending
visual confirmation; Sixel can be slower during scrolling. `<leader>cp` still
opens the full Markdown preview in a browser if terminal rendering misbehaves.

If images do not appear, ensure `magick` is on PATH
and install the Markdown parsers with `:TSInstall markdown markdown_inline`.

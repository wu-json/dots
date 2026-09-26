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

Move the cursor onto an image line (like `banner` above) to show a floating preview
with [Snacks image](https://github.com/folke/snacks.nvim/blob/main/docs/image.md).
Inline image rendering is disabled.

Run `just bootstrap brew` to install ImageMagick, reload your WezTerm configuration,
and restart Neovim. `<leader>cp` toggles the full Markdown preview in a browser.

If images do not appear, run `:checkhealth snacks`. The `markdown` and
`markdown_inline` Tree-sitter parsers must be installed (`:TSInstall markdown markdown_inline`).

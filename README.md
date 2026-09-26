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

[Snacks image](https://github.com/folke/snacks.nvim/blob/main/docs/image.md) displays
Markdown images using the existing Snacks plugin. Run `just bootstrap brew` to
install ImageMagick, then restart Neovim and reload your WezTerm configuration.

- **WezTerm:** move the cursor onto an image line (like `banner` above) to see a
  floating image preview. WezTerm does not support Snacks' inline images.
- **Kitty / Ghostty:** images appear inline in the document automatically.
- **Browser:** `<leader>cp` toggles the existing full Markdown preview, including
  images, regardless of terminal support.

If images do not appear, run `:checkhealth snacks`. The `markdown` and
`markdown_inline` Tree-sitter parsers must be installed (`:TSInstall markdown markdown_inline`).

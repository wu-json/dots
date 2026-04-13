# Dots

This is where I tweak config files till 4am like a goblin. It's pretty cozy in here.

![10d1d033-882c-4e25-b427-9b6c0ff7985b](https://github.com/user-attachments/assets/c0c99a76-39bc-4618-8a29-741b0904e2b6)

## My Cursed Tools

- **[Claude Code](https://code.claude.com/)** — This is going to take my job
- **[Cursor](https://cursor.com/)** — Agent + CLI; see setup note on macOS quarantine below
- **[fish](https://fishshell.com/)** — I eat the fish
- **[Homebrew](https://brew.sh/)** — Cyber alcoholic
- **[Neovim](https://neovim.io/)** — LazyVim-flavored (`lazyvim.json` in-tree)
- **[WezTerm](https://wezterm.org/index.html)** — lua lua lua
- **[GNU Stow](https://www.gnu.org/software/stow/)** — link those symmies

Full formula/cask list lives in [`homebrew/Brewfile`](homebrew/Brewfile).

## What's in this repo

[GNU Stow](https://www.gnu.org/software/stow/) packages (targets `~` when you run `just stow`):

| Package   | What it is                         |
| --------- | ---------------------------------- |
| `claude/` | Claude Code config                 |
| `cursor/` | Cursor CLI config (e.g. skills)    |
| `fish/`   | Fish shell                         |
| `nvim/`   | Neovim / LazyVim                   |
| `wezterm/`| WezTerm                            |

Also: `docs/` (notes/specs), `pickpocket.json` (pinned checkouts for the **pickpocket** CLI from Homebrew), and [`justfile`](justfile) for bootstrap.

## Setup

Install [just](https://github.com/casey/just) first (e.g. `brew install just`), then:

```bash
git clone https://github.com/wu-json/dots.git
cd dots
just init
```

`just init` runs, in order:

1. **`just brew`** — `brew bundle install` using `homebrew/Brewfile`. On macOS, if the **cursor-cli** cask is present, it clears Gatekeeper quarantine on that install so native addons (e.g. merkle-tree NAPI) load. If you use `brew bundle` without Just, run `xattr -rd com.apple.quarantine "$(brew --prefix)/Caskroom/cursor-cli/"` afterward. Background: [Cursor forum — merkle-tree NAPI / “not opened” on darwin-arm64](https://forum.cursor.com/t/cursor-agent-merkle-tree-napi-darwin-arm64-node-not-opened/155056).
2. **`just stow`** — Symlinks the packages above into your home directory.
3. **`just init-fish`** — Appends Homebrew’s `fish` to `/etc/shells` (with `sudo` if needed) and runs `chsh` so fish is your login shell.

If you do not want to change your login shell, run `just brew` and `just stow` only.

The `justfile` uses `/opt/homebrew` on macOS and `/home/linuxbrew/.linuxbrew` on Linux for Homebrew paths.

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

## Daily notes

Run `daily` from any directory to invoke `just daily` in your notes repository
and start Neovim in prose mode.
It finds a sibling of the dots checkout whose `justfile` lists a `daily` recipe.
Discovery only checks those immediate siblings and requires exactly one match.
If your repositories live elsewhere or multiple recipes match, set a local override:

```fish
set -Ux DAILY_NOTES_DIR /absolute/path/to/notes
```

For Neovim, configure the date format of the note path relative to that repository,
matching its `daily` recipe. For example:

```fish
set -Ux DAILY_NOTES_FORMAT '%Y-%m-%d.md'
```

`<leader>nd` opens today's note in prose mode in the existing Neovim session,
creating parent directories if needed. Use `<leader>p` to leave prose mode.
It uses the same Fish discovery and reads the local settings on each
invocation. These universal variables stay in local Fish state, outside version
control. The Neovim shortcut opens the file directly, so it does not run any other
recipe steps. Both shortcuts require the Fish configuration to be installed.

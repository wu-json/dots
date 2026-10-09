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
- **[Tinycast](https://github.com/abue-ammar/tinycast)**
- **[yazi](https://yazi-rs.github.io/)**

## Setup

```bash
bash scripts/bootstrap.sh
```

Tinycast's native [settings.json](tinycast/.config/tinycast/settings.json) is linked
to `~/.config/tinycast/settings.json` with Stow. On a new Mac, enable
**Settings → Backup → Settings File** and choose **Import**. Tinycast reads file
edits and saves UI preference changes back through the link.

Tinycast 0.11.12 excludes app and launcher shortcuts from its native file, so
[shortcuts.json](tinycast/.config/tinycast/shortcuts.json) stores those separately:
Command+Space for the launcher (key code 49, modifier 256), Option+W for WezTerm
(key code 13), Option+L for Linear (key code 37), and Option+H for Helium
(key code 4). All Option shortcuts use modifier 2048.
This is a dotfiles helper config, read by bootstrap.
Add app entries by bundle ID under `apps`; copy UI shortcut changes here before
rerunning setup. It manages the app shortcut list and preserves other preferences.

Full setup links the files and applies shortcuts, or run `just bootstrap tinycast`
on macOS. The recipe quits Tinycast before writing shortcuts and reopens it if it
was running.

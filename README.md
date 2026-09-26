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
brew install just
just init
```

### GitHub dashboard

`just init` installs gh-dash and gh-stack and links the dashboard configuration. On an existing machine, run
`just init-gh-extensions` and `just stow`, then restart Fish and Neovim.
Authenticate with `gh auth login` if needed.

Open the dashboard with `gh dash` (or `ghd` in Fish), or press `<Space>gd` in
Neovim for a floating terminal. Press `q` to quit and `?` for dashboard help.
The shared config includes your open PRs, review requests, and assigned issues.
Update the extension with `gh extension upgrade dash`.
The stacking extension is available as `gh stack`; update it with `gh extension upgrade stack`.

### Insomnia

On macOS, `just init` installs Insomnia in the menu bar and starts SwiftBar at login.
Run `just init-insomnia` to set up only Insomnia on an existing machine.
Click **Keep Mac Awake** in the eye menu, or press Control–Command–I.
The eye is outlined when off and filled when on.
Insomnia keeps the display and Mac awake until you turn it off. Its state resets after a reboot.

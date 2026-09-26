# Dots

This is where I tweak config files till 4am like a goblin. It's pretty cozy in here.

![banner](assets/banner.png)

## My Cursed Tools

- **[claude](https://code.claude.com/)**
- **[fish](https://fishshell.com/)**
- **[homebrew](https://brew.sh/)**
- **[neovim](https://neovim.io/)**
- **[pi](https://github.com/badlogic/pi-mono)**
- **[wezterm](https://wezterm.org/index.html)**
- **[stow](https://www.gnu.org/software/stow/)**
- **[yazi](https://yazi-rs.github.io/)**

## Setup

From a clone of this repo on macOS (primarily Apple Silicon):

```bash
bash scripts/init.sh bootstrap
```

The bootstrap installs Homebrew and `just` if missing, loads Homebrew's PATH,
then runs `just init`. Homebrew may request administrator access or Apple's
Command Line Tools; follow its instructions and rerun if installation stops.
A network connection is needed for missing packages. If Homebrew and `just`
are already available, run `just init` directly.

Setup installs missing Brewfile packages without requesting upgrades of existing ones,
links configs without overwriting existing files, and installs extension dependencies.
Existing configuration conflicts stop with instructions to move/back up the files.
Repeated runs report what is already configured and only apply missing setup.
GitHub authentication and an interactive login-shell change can be deferred;
warnings include the exact commands to finish those steps. Fish is installed
before shell setup, and its actual executable path and account login shell are checked.
Run `just init-fish` in a terminal to allow any required `sudo`/`chsh` prompts.

Individual `init-*` recipes also install their missing tool dependencies.
Pi requires Node 22.19 or newer; an older active runtime produces a warning with
a follow-up command instead of attempting an incompatible install.
`just init-obscura` and `just init-tailscale-cli` remain optional.
Use `NO_COLOR=1 just init` for plain output, or `DOTS_NONINTERACTIVE=1 just init`
to explicitly defer login-shell changes. Failures retain command diagnostics;
a failed required step returns a nonzero status, while optional skipped steps
are counted in the final summary. Linux support is best-effort; macOS app setup
is skipped there.

## Testing setup safely

```bash
just test
# Without just:
python3 -m unittest discover -s tests -v
```

Tests copy the setup files into temporary directories with disposable homes.
External installers, authentication, shell changes, and macOS services are
replaced with stateful command doubles on a restricted PATH. Homebrew discovery
paths in the copied script are redirected into the fixture too. They exercise
fresh setup, repeated runs, missing prerequisites, and failures without touching
your packages, login shell, preferences, or running apps. A separate integration
test uses real GNU Stow when available, targeting only the disposable home.
CI runs the same tests on macOS.

These tests validate orchestration, not live Homebrew downloads or macOS privilege
prompts. For a full installation smoke test, use a disposable macOS VM and run
`bash scripts/init.sh bootstrap` twice; do not use your daily account as a sandbox.

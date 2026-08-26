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
```bash
brew install just
just init
```

## Skills

`skills/<name>/SKILL.md` is the only file you edit. Each agent's skills dir (`claude/.claude/skills`, `pi/.pi/agent/skills`) is a symlink to `skills/`, so one copy is shared across all agents.

```yaml
---
name: <name>
description: One-line trigger blurb. "Use when the user asks for X."
---

# <name>

Body of the skill.
```

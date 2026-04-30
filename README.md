# Dots

This is where I tweak config files till 4am like a goblin. It's pretty cozy in here.

![banner](assets/banner.png)

## My Cursed Tools

- **[claude](https://code.claude.com/)** - this is going to take my job
- **[cursor](https://cursor.com/)** - this is also going to take my job
- **[fish](https://fishshell.com/)** - I eat the fish
- **[homebrew](https://brew.sh/)** - cyber alcoholic
- **[neovim](https://neovim.io/)** - female repellent
- **[pi](https://github.com/badlogic/pi-mono)** - this is also going to take my job
- **[wezterm](https://wezterm.org/index.html)** - lua lua lua
- **[stow](https://www.gnu.org/software/stow/)** - link those symmies

## Setup
```bash
brew install just
just init
```

## Skills

`skills/<name>/SKILL.md` is the only file you edit. Each agent's skills dir (`claude/.claude/skills`, `cursor/.cursor/skills`, `pi/.pi/agent/skills`) is a symlink to `skills/`, so one copy is shared across all three agents.

```yaml
---
name: <name>
description: One-line trigger blurb. "Use when the user asks for X."
---

# <name>

Body of the skill.
```

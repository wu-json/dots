brew_prefix := if os() == "macos" { "/opt/homebrew" } else { "/home/linuxbrew/.linuxbrew" }

brew:
  brew bundle install --file=homebrew/Brewfile

init-fish:
  grep -qxF "{{brew_prefix}}/bin/fish" /etc/shells || echo "{{brew_prefix}}/bin/fish" | sudo tee -a /etc/shells
  chsh -s {{brew_prefix}}/bin/fish

# macOS: App Store Tailscale ships no CLI launcher, so add the app's MacOS dir to fish's universal PATH. (Symlinks break Tailscale's bundle-identity check, hence PATH over symlink.)
init-tailscale-cli:
  #!/usr/bin/env bash
  set -euo pipefail
  if [ "$(uname -s)" != Darwin ]; then echo "skip: macOS only"; exit 0; fi
  if [ ! -x /Applications/Tailscale.app/Contents/MacOS/Tailscale ]; then echo "Tailscale.app not found"; exit 1; fi
  sudo rm -f /usr/local/bin/tailscale
  fish -c 'fish_add_path -U /Applications/Tailscale.app/Contents/MacOS'
  echo "✓ Tailscale MacOS dir added to fish's universal PATH"

# macOS: Obsidian's installer only appends to .zprofile, so fish misses the CLI. Add the app's MacOS dir to fish's universal PATH.
init-obsidian-cli:
  #!/usr/bin/env bash
  set -euo pipefail
  if [ "$(uname -s)" != Darwin ]; then echo "skip: macOS only"; exit 0; fi
  if [ ! -x /Applications/Obsidian.app/Contents/MacOS/Obsidian ]; then echo "Obsidian.app not found"; exit 1; fi
  sudo rm -f /usr/local/bin/obsidian
  fish -c 'fish_add_path -U /Applications/Obsidian.app/Contents/MacOS'
  echo "✓ Obsidian MacOS dir added to fish's universal PATH"

stow:
  stow -t ~ claude
  stow -t ~ fish
  stow -t ~ nvim
  stow -t ~ pi
  stow -t ~ wezterm
  stow -t ~ yazi

# Obscura (headless browser) ships prebuilt binaries but isn't on Homebrew, so fetch the release tarball into ~/.local/bin.
obscura_version := "0.1.8"
init-obscura:
  #!/usr/bin/env bash
  set -euo pipefail
  case "$(uname -s)" in
    Darwin) os=macos ;;
    Linux)  os=linux ;;
    *) echo "unsupported OS: $(uname -s)"; exit 1 ;;
  esac
  case "$(uname -m)" in
    arm64|aarch64) arch=aarch64 ;;
    x86_64)        arch=x86_64 ;;
    *) echo "unsupported arch: $(uname -m)"; exit 1 ;;
  esac
  asset="obscura-${arch}-${os}.tar.gz"
  url="https://github.com/h4ckf0r0day/obscura/releases/download/v{{obscura_version}}/${asset}"
  mkdir -p ~/.local/bin
  tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
  echo "downloading $asset ..."
  curl -fsL "$url" -o "$tmp/o.tar.gz"
  tar xzf "$tmp/o.tar.gz" -C ~/.local/bin obscura obscura-worker
  chmod +x ~/.local/bin/obscura ~/.local/bin/obscura-worker
  # Strip Gatekeeper quarantine on macOS so the binary runs without a prompt.
  [ "$os" = macos ] && xattr -d com.apple.quarantine ~/.local/bin/obscura ~/.local/bin/obscura-worker 2>/dev/null || true
  echo "✓ installed $(~/.local/bin/obscura --version)"

init: brew stow init-fish
  @echo "✓ Initialization complete!"

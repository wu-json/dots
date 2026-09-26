brew:
  @bash scripts/bootstrap.sh brew

init:
  @bash scripts/bootstrap.sh init

init-gh-extensions:
  @bash scripts/bootstrap.sh gh

init-insomnia:
  @bash scripts/bootstrap.sh insomnia

init-fish:
  @bash scripts/bootstrap.sh fish

init-obscura:
  @bash scripts/bootstrap.sh obscura

init-pi-extensions:
  @bash scripts/bootstrap.sh pi

init-tailscale-cli:
  @bash scripts/bootstrap.sh tailscale

stow:
  @bash scripts/bootstrap.sh stow

test:
  @python3 tests/integration.py

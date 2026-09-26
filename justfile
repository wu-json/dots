brew:
  @bash scripts/bootstrap.sh brew

bootstrap:
  @bash scripts/bootstrap.sh bootstrap

bootstrap-gh-extensions:
  @bash scripts/bootstrap.sh gh

bootstrap-insomnia:
  @bash scripts/bootstrap.sh insomnia

bootstrap-fish:
  @bash scripts/bootstrap.sh fish

bootstrap-obscura:
  @bash scripts/bootstrap.sh obscura

bootstrap-pi-extensions:
  @bash scripts/bootstrap.sh pi

bootstrap-tailscale-cli:
  @bash scripts/bootstrap.sh tailscale

stow:
  @bash scripts/bootstrap.sh stow

test:
  @python3 tests/integration.py

brew:
  @bash scripts/init.sh brew

init:
  @bash scripts/init.sh init

init-gh-extensions:
  @bash scripts/init.sh gh

init-insomnia:
  @bash scripts/init.sh insomnia

init-fish:
  @bash scripts/init.sh fish

init-obscura:
  @bash scripts/init.sh obscura

init-pi-extensions:
  @bash scripts/init.sh pi

init-tailscale-cli:
  @bash scripts/init.sh tailscale

stow:
  @bash scripts/init.sh stow

test:
  @python3 -m unittest discover -s tests -v

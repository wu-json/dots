set positional-arguments

bootstrap target="all":
  @bash scripts/bootstrap.sh "$1"

test:
  @python3 tests/integration.py

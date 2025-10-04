# King In The Hill (Sui Move)

A small Sui Move example module that implements a simple "King of the Hill" shared object with capture logic and test utilities.

## What it is

This repository contains a Move package (`Move.toml`) and a `king_in_the_hill` module that models a `KingHill` shared object. The module provides functions to create and share the object (test-only helpers), capture the hill (updating the current king and timestamp), and read view functions for testing.

## How to run tests

Make sure you have the Sui developer toolchain installed. From the repository root run:

```bash
sui move test
```

All tests are implemented under `tests/king_in_the_hill_tests.move` and use `sui::test_scenario` utilities.

## Notes and tips

- Tests use synthetic timestamps rather than the `Clock` object to avoid issues with types that do not have the `drop` ability.
- The test helper `init_game` creates and shares a `KingHill` and then calls `ts::next_tx` to commit the shared object to the test scenario inventory.
- There are harmless linter warnings about duplicate aliases in `sources/king_in_the_hill.move` which can be cleaned up by removing redundant `use` aliases.

## Contributing

- Open an issue or PR for changes.
- If editing tests or the module, run `sui move test` to verify changes.

## License

No license specified. Add one to `Move.toml` and this README if you intend to publish.

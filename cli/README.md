# `cli` — struct-based argument parser

> **Status:** planned (Tier 1 #2, see `../../ZIG_STD_LIB_AUDIT.md`)

## Why

Zig std has `process/Args.zig` — a low-level argv iterator. No flag parsing, no subcommands, no help text generation.

## Scope (planned)

- Parse argv into a user-defined struct (clap-style, but minimal)
- Flags: long (`--name`), short (`-n`), value (`--key=val`, `--key val`)
- Positional args
- Subcommands
- Auto-generated `--help` and version
- Type coercion: bool, int, float, string, list

## Non-goals (deliberate)

- ❌ Bash-style argument parsing (use IteratorGeneral for that)
- ❌ Config-file merging (use `toml` lib)
- ❌ Plugin/completion scripts
- ❌ Posix/GNU flag conventions conflict resolution (pick one, document it)

## Stability promise

- Same as project: API frozen at 0.1.0
- v0.1.0 ships: minimal flag + positional + help
- v0.2.0+: subcommands, list types (additive)

## Reference

See `ZIG_STD_LIB_AUDIT.md` §1, gap #2.

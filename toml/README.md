# `toml` — Cargo-grade config parser

> **Status:** planned (Tier 1 #3, see `../../ZIG_STD_LIB_AUDIT.md`)

## Why

Zig std has `json` (full) + `zon` (Zig's own format) but no TOML. Many tools want `Cargo.toml`-style config.

## Scope (planned)

- TOML 1.0 spec compliance
- Parse into `std.json.Value`-like dynamic tree
- Serialize from dynamic tree
- Round-trip preservation of comments, whitespace
- Strict error reporting (line + column)

## Non-goals (deliberate)

- ❌ TOML 0.5 / 0.4 compatibility
- ❌ Schema validation (use a separate lib for that)
- ❌ JSON ↔ TOML converter
- ❌ Streaming parser (load whole file in memory; configs are small)

## Stability promise

- API frozen at 0.1.0
- v0.1.0: parse + dynamic tree
- v0.2.0: serialize
- v0.3.0: round-trip

## Reference

See `ZIG_STD_LIB_AUDIT.md` §1, gap #3.

# Changelog — `toml`

Format: [Keep a Changelog](https://keepachangelog.com)

## [0.1.0] - 2026-06-13

First stable release. API frozen.

### Added
- `parse(arena, source) ParseError!Value` — full TOML 1.0 parser
- `Value` tagged union: `string`, `integer`, `float`, `boolean`, `datetime`, `array`, `table: *Table`
- `Value.Table` struct (key-value entries, preserving source order)
- `Value.Table.Entry` struct
- `ParseError` set: `InvalidSyntax`, `UnterminatedString`, `InvalidNumber`, `InvalidDatetime`, `DuplicateKey`, `EmptyKey`, `OutOfMemory`
- `get`, `getString`, `getInt`, `getFloat`, `getBool`, `getTable`, `getArray`, `getPath`
- String parsing: basic `"..."`, literal `'...'`, multi-line `"""..."""`
- Number parsing: integer, float, scientific notation, `inf`/`-inf`/`nan`, underscores
- Datetime parsing (stored as RFC 3339 string in v0.1.0)
- Tables: regular `[name]`, inline `{...}`, nested via dotted keys
- Array of tables: `[[name]]`
- Quoted keys: `"key with spaces" = ...`
- Comments (`#`) ignored
- 24 tests covering all of the above

### Notes
- `Value.table` is a `*Table` pointer (stable address for navigation)
- All accessors take `*const Value.Table` — pass `v.table` directly
- Datetime uses `.datetime` variant (not `.string`) — access via `get(...).?.datetime`
- Arena ownership: caller manages lifetime
- API frozen at this version. No breaking changes until 1.0.0

### Deferred to v0.2.0
- Serialize / round-trip preservation
- Line/column in error variants
- Datetime as separate type (currently stored as RFC 3339 string)
- BigInt (currently capped at i64)

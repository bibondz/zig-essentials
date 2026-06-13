# Changelog — `toml`

Format: [Keep a Changelog](https://keepachangelog.com)

## [0.1.0-dev] — unreleased

### Added
- Design: parse TOML 1.0 text into dynamic `Value` tree
- Type definitions: `Value` (tagged union), `Value.Table`, `Value.Table.Entry`
- Public API: `parse(arena, source)`, `get`, `getString`/`getInt`/`getFloat`/`getBool`/`getTable`/`getArray`, `getPath`
- `ParseError` set: `InvalidSyntax`, `UnterminatedString`, `InvalidNumber`, `InvalidDatetime`, `DuplicateKey`, `EmptyKey`, `OutOfMemory`
- Stub impl (returns `ParseError.InvalidSyntax`) so tests can be RED
- 24 RED tests covering: 11 basic types, 3 arrays, 6 tables, 4 errors
- README with design doc + scope matrix + out-of-scope list

### Pending (next session)
- `parse()` impl — TDD: GREEN all 24 tests
- After GREEN: refactor (TDD step 3)

### Deferred to v0.2.0
- Serialize / round-trip preservation
- Line/column in error variants
- Datetime as separate type (currently stored as RFC 3339 string)
- BigInt (currently capped at i64)

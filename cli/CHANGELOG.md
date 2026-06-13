# Changelog — `cli`

Format: [Keep a Changelog](https://keepachangelog.com)

## [0.1.0] - 2026-06-13

First stable release. API frozen.

### Added
- `parse(comptime T: type, comptime schema: Schema, arena: Allocator, argv: []const []const u8) ParseError!T`
- Type definitions: `Kind` (`.flag`/`.option`/`.option_list`), `Opt`, `Positional`, `Schema`, `ParseError`
- Long flags (`--name`), short flags (`-n`), combined shorts (`-vfd` for bools)
- Options with values: `--name=val`, `--name val`, `-n val`, `-nval`
- Positional args: required / optional / `many` (comma-joined via arena)
- Auto `--help` / `-h` / `--version` (when `schema.version` set)
- Compile-time schema↔struct check via `@hasField`
- 18 tests: 12 success cases, 5 error cases, 2 help/version

### Notes
- `parse()` takes an `arena: Allocator` for the `many` positional case (joins values with `,`)
- API frozen at this version. No breaking changes until 1.0.0

### Deferred to v0.2.0
- Subcommands
- `--no-flag` negation
- Custom validators
- Type coercion (int/float from string)

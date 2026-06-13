# Changelog — `cli`

Format: [Keep a Changelog](https://keepachangelog.com)

## [0.1.0-dev] — unreleased

### Added
- Design: declarative schema (comptime literal), parses to user struct
- Type definitions: `Kind`, `Opt`, `Positional`, `Schema`, `ParseError`
- Public API: `parse(T, schema, argv)`
- Stub impl (returns `ParseError.Todo`) so tests can be RED
- 18 RED tests covering: success cases, error cases, help/version
- README with design doc + out-of-scope list + test coverage breakdown

### Pending (next session)
- `parse()` impl — TDD: GREEN all 18 tests
- `printHelp()` and `printVersion()` for caller to use when `HelpRequested`/`VersionRequested` returned
- After GREEN: refactor (TDD step 3)

### Deferred to v0.2.0
- Subcommands
- `--no-flag` negation
- Custom validators

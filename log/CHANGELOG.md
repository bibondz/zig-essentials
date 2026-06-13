# Changelog — `log`

Format: [Keep a Changelog](https://keepachangelog.com)

## [0.1.0-dev] — unreleased

### Added
- Design: pluggable `Sink` (text + JSON), drop-in compatible with `std.log`
- Type definitions: `Level`, `Sink`, `Logger`
- Public API: `setSink`, `unsetSink`, `setLevel`, `textSink`, `jsonSink`, `textSinkToStderr`
- `scoped("name")` returns a `Logger` with the given scope (string, not enum literal — see README why)
- Top-level `log.debug/info/warn/err("scope", fmt, args)`
- Stub impl — all public functions are no-ops until impl lands
- 15 RED tests covering sink construction, level filtering, logger output, sink format, drop-in compatibility
- README with design doc, scope choice rationale, out-of-scope list

### Pending (next session)
- `Sink.writeFn` impl for text and JSON sinks
- `setSink`/`unsetSink` global state management
- `setLevel` runtime filter
- `logAtLevel` dispatch with level check
- After GREEN: refactor (TDD step 3)

### Deferred to v0.2.0
- Caller file:line in sink output
- Structured fields (key-value pairs)
- `std.log.scoped` enum literal compat overload

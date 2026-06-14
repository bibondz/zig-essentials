# Changelog

Per-package changelogs live in `<package>/CHANGELOG.md`. This file is the **cross-package summary**, newest first.

Format: [Keep a Changelog](https://keepachangelog.com)

## [unreleased] - 2026-06-13

### Added
- `toml` v0.1.0 (TOML 1.0 parser; 24/24 tests)
- `log` v0.1.0 (structured logger; 17/17 tests)
  - Drop-in compatible with `std.log`
  - Pluggable sinks: text, JSON, stderr
  - Per-call level (`debug`/`info`/`warn`/`err`) and scope
  - Runtime level filtering via `setLevel`
  - **Breaking change**: `Sink.writeFn` signature changed from `*const fn(..., comptime fmt, fmt_args: anytype)` to `*const fn(..., message: []const u8)`. Custom sink implementers must update their `writeFn`.
- `watcher` v0.1.0-dev (filesystem watcher; 11 RED tests — stub + platform scaffolding)

### Released
- `uuid` v0.1.0 (RFC 4122/9562 v4 + v7At, parse, format; 23/23 tests)
- `cli` v0.1.0 (struct-based arg parser; 18/18 tests)

### Also included
- `PROJECT_PLAN.md` — design principles, LTS policy, release process
- `ZIG_STD_LIB_AUDIT.md` — 8 verified gaps in Zig 0.16 std
- `CONTRIBUTING.md`, `SECURITY.md` — community + security policies
- CI workflow stub (`.forgejo/workflows/test.yml`)
- LICENSE (MIT)
- `.gitignore`, `.gitattributes`

### Verified on
- Zig 0.16.0 stable (LTS-0.16)
- Windows x86_64 (cross-OS testing pending CI)

### Planned
- `regex` (PCRE subset, NFA-based; Tier 2 #5)
- `websocket` (RFC 6455 client + server; Tier 3 #6)
- `tracing` (OpenTelemetry-style spans; Tier 3 #8)

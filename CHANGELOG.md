# Changelog

Per-package changelogs live in `<package>/CHANGELOG.md`. This file is the **cross-package summary**, newest first.

Format: [Keep a Changelog](https://keepachangelog.com)

## [unreleased] - 2026-06-13

### Added
- `toml` v0.1.0 (TOML 1.0 parser; 24/24 tests)
- `log` v0.1.0-dev design + 15 RED tests (impl in next session)

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
- `regex`, `websocket`, `watcher`, `tracing` (per PROJECT_PLAN.md §8)

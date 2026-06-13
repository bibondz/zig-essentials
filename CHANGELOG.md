# Changelog

Per-package changelogs live in `<package>/CHANGELOG.md`. This file is the **cross-package summary**, newest first.

Format: [Keep a Changelog](https://keepachangelog.com)

## [unreleased]

### Added
- Project bootstrap: monorepo, PROJECT_PLAN.md, ZIG_STD_LIB_AUDIT.md, LICENSE (MIT)
- `uuid` v0.1.0-dev feature-complete: v4, v7At, parse, format, accessors; 23/23 tests pass
- CI workflow stub: `.forgejo/workflows/test.yml` (Codeberg/Forgejo compatible)
- `.gitattributes` for line endings

### Changed
- Re-verified `ZIG_STD_LIB_AUDIT.md` on installed Zig 0.16.0 std lib (was previously on 0.17-dev master). 8 gaps confirmed identical.
- KB re-indexed with `zig-0.16-std:*` labels (replacing `zig-std:*` which pointed to deleted `zig-current/` checkout)
- `PROJECT_PLAN.md §12` added: LTS upgrade workflow + audit refresh procedure
- `PROJECT_PLAN.md §13` added: release process (bump protocol, release steps, EOL policy)

### Added
- `CONTRIBUTING.md`: TDD, no LLM, public API change policy, commit format
- `SECURITY.md`: reporting process, severity, disclosure, supported versions
- `cli` v0.1.0-dev design + 18 RED tests (impl deferred to next session)

### Removed
- `D:/acko/zig-current/` (307 MB, was unused 0.17-dev checkout, now deleted)
- `D:/acko/ZIG_STD_LIB_AUDIT.md` (duplicate at root, canonical copy in essentials/)

### Planned
- `cli`, `toml`, `log`, `regex`, `websocket`, `watcher`, `tracing` (per PROJECT_PLAN.md §8)

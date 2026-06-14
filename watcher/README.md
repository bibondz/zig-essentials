# `watcher` — cross-platform filesystem watcher

> **Status:** v0.1.0-dev (in progress — stub + 11 RED tests)

## Why

Zig std has no inotify / FSEvents / ReadDirectoryChangesW wrapper. Build tools, dev servers, file-sync tools all need it.

## Scope (planned)

- Cross-platform: Linux (inotify), macOS (FSEvents), Windows (ReadDirectoryChangesW)
- Per-path subscription
- Event types: created, modified, deleted, renamed, moved-out, moved-in
- Recursive watch (per directory, not auto-recursive — caller walks)
- Coalescing (debounce near-simultaneous events)

## Non-goals (deliberate)

- ❌ Polling-based fallback (use OS-native or don't ship)
- ❌ inotify's cookie / rename pairing (best-effort, document the gap)
- ❌ Editor-style "watch project, ignore `node_modules`" — that's a separate lib
- ❌ Network filesystem watchers (NFS, SMB) — too unreliable

## Stability promise

- API frozen at 0.1.0
- v0.1.0: Linux only, per-path, basic events
- v0.2.0: macOS support
- v0.3.0: Windows support

## Reference

See `ZIG_STD_LIB_AUDIT.md` §1, gap #6.

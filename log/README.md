# `log` — structured logger

> **Status:** planned (Tier 2 #4, see `../../ZIG_STD_LIB_AUDIT.md`)

## Why

Zig std has `log.zig` — text-only, single line, no structure. Production services need JSON or other machine-parseable formats, and `std.log` doesn't expose a way to change the sink.

## Scope (planned)

- Drop-in replacement for `std.log`'s public API
- Pluggable sink: text (default), JSON, custom
- Level filtering per scope
- Per-call fields (key-value pairs)
- Caller file:line capture
- No allocation in hot path (sinks that need to allocate, do so once per call)

## Non-goals (deliberate)

- ❌ Async/shipping to remote (use OTel collector instead — see `tracing` lib)
- ❌ Log rotation (do at the OS / `logrotate` level)
- ❌ Pretty colors in production sink (terminal sink only)
- ❌ Replace `std.log` (we extend, not fork)

## Stability promise

- API frozen at 0.1.0
- v0.1.0: text + JSON sinks, scope, levels
- v0.2.0: fields (key-value)
- v0.3.0: caller capture

## Reference

See `ZIG_STD_LIB_AUDIT.md` §1, gap #7.

# `log` — structured logger for Zig

> **Status:** v0.1.0-dev (TDD RED — impl in next session)
> 15/15 tests failing by design until impl lands

Fills the gap in std: Zig 0.16 `std.log` is text-only with no structured sink option. Verified via `ZIG_STD_LIB_AUDIT.md`.

## What you get (when impl lands)

```zig
const std = @import("std");
const log = @import("log");

// Drop-in usage (similar to std.log)
const my_log = log.scoped("myapp");
my_log.info("starting up v{d}", .{1});
// → "info(myapp): starting up v1\n"

// Switch to JSON sink
var buf: [4096]u8 = undefined;
var writer = std.Io.Writer.fixed(&buf);
log.setSink(log.jsonSink(arena.allocator(), &writer));
my_log.info("user signed in");
// → {"level":"info","scope":"myapp","message":"user signed in"}\n

// Reset to default text-to-stderr
log.unsetSink();

// Filter to warn and above
log.setLevel(.warn);
```

## Design (v0.1.0)

| Feature | Status |
|---|---|
| Drop-in compatible with `std.log` API (mostly) | ✅ |
| Pluggable `Sink` (text + JSON) | ✅ |
| Per-call level: `debug` / `info` / `warn` / `err` | ✅ |
| Per-call scope (comptime string for v0.1.0) | ✅ |
| Runtime level filter via `setLevel` | ✅ |
| Compile-time format strings | ✅ |
| `textSink(writer)` → human-readable text | ✅ |
| `jsonSink(allocator, writer)` → one JSON object per line | ✅ |
| **Caller file:line** | ⏳ v0.2.0 |
| **Structured fields** (key-value pairs) | ⏳ v0.2.0 |
| **Async/background thread** | ⏳ v0.3.0+ |
| **Caller capture** (caller's `[]const u8` for extra context) | ❌ v0.2.0 |

## Why string scope (not std.log's enum literal)?

`std.log.scoped` takes `@EnumLiteral()` which is fragile in Zig 0.16's strict typing. We use `comptime scope: []const u8` instead — simpler, no enum type needed.

If there's strong demand for `std.log`-style enum compat, we can add it in v0.2.0.

## API surface (frozen at 0.1.0)

| Type / function | Stable? |
|---|---|
| `log.Level` (`.debug` / `.info` / `.warn` / `.err`) | ✅ |
| `log.Sink` struct | ✅ |
| `log.Logger` struct (`.debug` / `.info` / `.warn` / `.err` methods) | ✅ |
| `log.setSink`, `log.unsetSink` | ✅ |
| `log.setLevel` | ✅ |
| `log.textSink(writer)`, `log.jsonSink(allocator, writer)` | ✅ |
| `log.textSinkToStderr()` | ✅ |
| `log.scoped("scope")` | ✅ |
| `log.debug/info/warn/err("scope", fmt, args)` | ✅ |
| `log.logAtLevel(level, scope, fmt, args)` | ✅ |

## Out of scope (deliberate)

- **Async/threaded sinks** — v0.1.0 is synchronous. Use a buffered Writer if you need throughput.
- **Pretty colors in production** — terminal sinks can be added later as a separate lib.
- **Log rotation** — filesystem concern, not our job.
- **Replace `std.options.logFn`** — we provide our own global state, not the std one.

## Build / test

```bash
cd log
zig build test
```

Currently: 0/15 pass (TDD RED). Next session: impl + GREEN.

## Test coverage (15 RED tests)

**Sink construction (3):**
- `textSink` produces a non-null sink
- `jsonSink` produces a non-null sink
- `textSinkToStderr` is constructible

**Global state (1):**
- `setSink` / `unsetSink` roundtrip

**Level filtering (4):**
- `setLevel(.warn)` filters below
- default level is `.debug`
- `.info` filter behavior
- `.err` filter behavior

**Logger output (4):**
- `Logger.debug` emits at debug level
- `Logger.info` emits at info level
- `Logger.warn` emits at warn level
- `Logger.err` emits at err level

**Sink format (2):**
- text sink format: `<level>(<scope>): <message>`
- JSON sink format: includes `level`, `scope`, `message` keys

**Compatibility (1):**
- drop-in: `log.info` matches `std.log.info` signature

## Stability promise

- All public functions frozen at 0.1.0
- New sinks (e.g., syslog, file) can be added without breaking changes (they're just function-returning Sinks)
- New levels would be a major version (current set is the de-facto standard)

## License

MIT.

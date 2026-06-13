# `uuid` — RFC 4122/9562 v4 + v7

Stable, minimal, explicit UUID library. Fills the gap in Zig `std` (verified via `ZIG_STD_LIB_AUDIT.md`).

## Status

**v0.1.0** — first stable release. API frozen. 23/23 tests pass on Zig 0.16.0.

## What you get

```zig
const std = @import("std");
const uuid = @import("uuid");

// v4: random
var prng = std.Random.DefaultPrng.init(0xdeadbeef);
const id_a = uuid.Uuid.v4(prng.random());
// e.g. "f4d1c2b3-a4b5-4687-9abc-def012345678"

// v7: time-ordered random (sortable by creation time) — pass your own timestamp
// (Zig 0.16 has no built-in milliTimestamp; use Io.Clock or posix.clock_gettime)
const id_c = uuid.Uuid.v7At(prng.random(), 1718000000000);  // explicit timestamp

// Accessors
_ = id_a.version();      // .v4
_ = id_a.isRfc4122();    // true
```

> **Note:** example uses `Uuid.format` which writes to a `std.Io.Writer`. For
> `*std.io.Writer` (legacy), wrap with `bufferedWriter`.

## API surface (frozen at 0.1.0)

| Function | Stable? | Note |
|---|---|---|
| `Uuid.v4(r: Random)` | ✅ | CSPRNG required |
| `Uuid.v7(r: Random)` | ❌ removed | Use `v7At` with your own timestamp (Zig 0.16 removed `std.time.milliTimestamp`) |
| `Uuid.v7At(r: Random, ts_ms: u64)` | ✅ | Explicit timestamp — caller chooses clock source |
| `Uuid.parse(s: []const u8) ParseError!Uuid` | ✅ | Canonical 8-4-4-4-12 or compact 32-hex, case-insensitive |
| `Uuid.format(self, w: anytype) !void` | ✅ | Writer-compatible (`*std.io.Writer` or `*std.Io.Writer`) |
| `Uuid.version() -> Version` | ✅ | |
| `Uuid.isRfc4122() -> bool` | ✅ | |

## Build / test

```bash
cd uuid
zig build test
```

## Non-goals (deliberate)

- v1, v3, v5, v6, v8 (add only when a real use case appears)
- Microsoft brace form `{...}` and `urn:uuid:` prefix
- Database-specific types (use `[16]u8` directly)
- Non-canonical string formats

## Stability promise

- `Uuid` layout (`extern struct`, 16 bytes) is **frozen**
- Public function signatures are **frozen at 0.1.0**
- New functionality = new functions, not signature changes
- Deprecation cycle: 2 minor versions minimum

## License

MIT.

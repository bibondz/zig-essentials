# toml v0.1.0 — first stable release

First stable release of `toml` — TOML 1.0 parser for Zig.

**24/24 tests pass** on Zig 0.16.0. API frozen.

## What's in this release

`toml` parses TOML 1.0 text into a dynamic `Value` tree. Arena-backed. Stable, explicit, minimal.

```zig
const std = @import("std");
const toml = @import("toml");

var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
defer arena.deinit();

const v = try toml.parse(arena.allocator(),
    \\[package]
    \name = "myapp"
    \version = "1.0.0"
    \\
    \\[dependencies]
    \zig = "0.16.0"
);

const name = toml.getString(v.table, "name").?;        // "myapp"
const zig_dep = toml.getString(
    toml.getTable(v.table, "dependencies").?,
    "zig"
).?;
```

## Features (v0.1.0)

- String (basic, literal, multi-line)
- Integer (positive, negative, underscores)
- Float (decimal, scientific, `inf`/`-inf`/`nan`, underscores)
- Boolean
- Datetime (stored as RFC 3339 string — v0.2.0 will have a structured type)
- Array (heterogeneous, multi-line)
- Tables: regular `[name]`, inline `{...}`, nested via dotted keys
- Array of tables: `[[name]]`
- Quoted keys: `"key with spaces" = ...`
- Comments (`#`) ignored

## API surface (frozen at v0.1.0)

| Type / function | Stable? |
|---|---|
| `toml.Value` (tagged union) | ✅ |
| `toml.Value.Table`, `toml.Value.Table.Entry` | ✅ |
| `toml.ParseError` (7 variants) | ✅ |
| `parse(arena, source) ParseError!Value` | ✅ |
| `get`, `getString`, `getInt`, `getFloat`, `getBool` | ✅ |
| `getTable`, `getArray`, `getPath` | ✅ |

## Install

Add as a dependency in your `build.zig.zon`:

```zon
.dependencies = .{
    .toml = .{
        .url = "https://github.com/bibondz/zig-essentials/archive/refs/tags/toml-v0.1.0.tar.gz",
        // hash filled by `zig build` on first use
    },
},
```

(Or copy `toml/src/toml.zig` directly — single-file, no deps.)

## Deferred to v0.2.0

- Serialize / round-trip
- Line/column in errors
- Datetime as separate type
- BigInt (i128+)

## See also

- [README.md](https://github.com/bibondz/zig-essentials/blob/main/toml/README.md) — full design doc
- [ZIG_STD_LIB_AUDIT.md](https://github.com/bibondz/zig-essentials/blob/main/ZIG_STD_LIB_AUDIT.md) — why this lib
- [PROJECT_PLAN.md](https://github.com/bibondz/zig-essentials/blob/main/PROJECT_PLAN.md) — versioning policy

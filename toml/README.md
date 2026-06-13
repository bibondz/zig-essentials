# `toml` — TOML 1.0 parser

> **Status:** v0.1.0-dev (TDD RED — impl in next session)
> 24/24 tests failing by design until impl lands

Fills the gap in std: Zig 0.16 std has no TOML parser. Verified via `ZIG_STD_LIB_AUDIT.md`.

## What you get (when impl lands)

```zig
const std = @import("std");
const toml = @import("toml");

var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
defer arena.deinit();

const src =
    \\[package]
    \name = "myapp"
    \version = "1.0.0"
    \\
    \[dependencies]
    \zig = "0.16.0"
    \authors = ["alice", "bob"]
;

const v = try toml.parse(arena.allocator(), src);

// Typed accessors
const name = toml.getString(v.table, "name").?;        // "myapp"
const version = toml.getString(v.table, "version").?; // "1.0.0"

// Nested via dotted keys
const zig_dep = toml.getString(
    toml.getTable(v.table, "dependencies").?,
    "zig"
).?;

// Or use getPath
const name_via_path = toml.getPath(v, &.{ "package", "name" }).?;
```

## Design (v0.1.0)

| Feature | Status |
|---|---|
| String (basic `"..."`, literal `'...'`, multi-line `"""..."""`) | ✅ |
| Integer (positive, negative, `_` separator) | ✅ |
| Float (decimal, scientific, `inf`/`-inf`/`nan`) | ✅ |
| Boolean (`true`/`false`) | ✅ |
| Datetime (stored as RFC 3339 string in v0.1.0) | ✅ |
| Array (heterogeneous, multi-line) | ✅ |
| Inline table `{ k = v, ... }` | ✅ |
| Regular table `[name]` | ✅ |
| Array of tables `[[name]]` | ✅ |
| Dotted keys (`a.b.c = 1`) | ✅ |
| Quoted keys (`"key with spaces" = 1`) | ✅ |
| Comments (`#` to end of line) — ignored | ✅ |
| **Serialize / round-trip** | ⏳ v0.2.0 |
| **Line/column in error** | ⏳ v0.2.0 |
| **Datetime as separate type** | ⏳ v0.2.0 |
| **BigInt (i128+)** | ❌ v0.1.0 caps at i64 |
| **Schema validation** | ❌ (separate lib) |
| **JSON ↔ TOML converter** | ❌ (too niche) |
| **Multi-document / include** | ❌ (v0.3.0+ if at all) |

## API surface (frozen at 0.1.0)

| Type / function | Stable? |
|---|---|
| `toml.Value` (tagged union: string, integer, float, boolean, datetime, array, table) | ✅ |
| `toml.Value.Table` (struct: entries []Entry) | ✅ |
| `toml.ParseError` (7 variants) | ✅ |
| `parse(arena, source) ParseError!Value` | ✅ |
| `get(t, key) ?Value` | ✅ |
| `getString`, `getInt`, `getFloat`, `getBool` | ✅ |
| `getTable`, `getArray` | ✅ |
| `getPath(root, path) ?Value` | ✅ |

## Build / test

```bash
cd toml
zig build test
```

Currently: 0/24 pass (TDD RED). Next session: impl + GREEN.

## Test coverage (24 RED tests)

**Basic types (11):**
- empty source → empty table
- simple string, literal string
- integer: positive, negative, underscore
- float: basic, scientific
- boolean: true, false
- datetime (as string)

**Arrays (3):**
- array of integers
- array of mixed types
- multi-line array

**Tables (6):**
- regular table
- nested tables via dotted keys
- inline table
- array of tables
- getPath walking
- comments ignored

**Errors (4):**
- duplicate key in same table
- unterminated string
- invalid number
- empty key

## Non-goals (deliberate)

Per `PROJECT_PLAN.md` principles (explicit/robust/practical/stable):
- v0.1.0 is **parse-only**. Round-trip is v0.2.0 because it doubles the surface.
- We don't preserve comments. TOML allows them; we ignore. If you need them, use a different lib or wait for v0.2.0.
- We don't implement a schema validator. Use a separate lib like `zig-schema` (if it exists) or write your own.
- We don't translate between TOML and JSON. Use `std.json` for JSON.

## Stability promise

- `parse(arena, source)` signature frozen at v0.1.0
- `Value` tagged union variants frozen (datetime may get a separate type in v0.2.0 — that's an additive change, not breaking)
- New error variants may be added; existing ones won't be removed
- Helper functions may be added; existing ones won't change

## License

MIT.

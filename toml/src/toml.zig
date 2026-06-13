//! `toml` — TOML 1.0 parser for Zig.
//!
//! Fills the gap in std (verified via `ZIG_STD_LIB_AUDIT.md`).
//!
//! ## Design (v0.1.0)
//!
//! - Parse TOML 1.0 text into a dynamic `Value` tree
//! - Arena allocator backs all allocations (tables, arrays, joined strings)
//! - Strict error set on invalid input
//! - Compile-time-friendly: `Value` is a tagged union, no reflection needed
//!
//! ## Supported (v0.1.0)
//!
//! - Basic value types: string (basic + literal + multi-line), integer, float, boolean, datetime
//! - Floats: `inf`, `-inf`, `nan`, `+inf`, `-nan`; underscores; scientific notation
//! - Integers: positive/negative; underscores
//! - Arrays (heterogeneous, multi-line)
//! - Tables: regular `[name]`, inline `{...}`, nested via dotted keys
//! - Array of tables `[[name]]`
//! - Quoted keys: `"key with spaces" = ...`
//! - Comments (`#` and inline) — ignored, not preserved
//!
//! ## Out of scope (deferred)
//!
//! - **Serialize / round-trip** (v0.2.0)
//! - **Line/column in error** (v0.2.0)
//! - **Schema validation** (separate lib)
//! - **JSON ↔ TOML converter** (never — too niche)
//! - **Multi-document / include** (v0.3.0+)
//! - **Datetime as separate type** (v0.2.0 — stored as RFC 3339 string in v0.1.0)
//! - **Huge integer support** (v0.1.0 caps at i64; underscore syntax accepted)
//!
//! ## Stability
//!
//! API frozen at 0.1.0. New features = new functions, not signature changes.

const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;

// ---------- Public types ----------

/// Single TOML value. Tagged union covering all TOML 1.0 value types.
///
/// For v0.1.0, datetime is stored as a string (RFC 3339 format). A dedicated
/// `Datetime` type is planned for v0.2.0.
pub const Value = union(enum) {
    /// String value. Includes basic `"..."`, literal `'...'`, and multi-line
    /// `"""..."""`. v0.1.0 doesn't distinguish these in the API.
    string: []const u8,
    /// Integer value. TOML allows arbitrary precision; v0.1.0 caps at `i64`.
    /// Underscores for readability (`1_000_000`) are accepted.
    integer: i64,
    /// Float value. Underscores, scientific notation, and special values
    /// (`inf`, `-inf`, `nan`, `+inf`, `-nan`) are supported.
    float: f64,
    /// Boolean: `true` or `false`.
    boolean: bool,
    /// Datetime. v0.1.0: stored as the original RFC 3339 string (no parsing
    /// into a structured type). v0.2.0: separate `Datetime` type.
    datetime: []const u8,
    /// Array of values. Heterogeneous types allowed (`[1, "two", 3.0]`).
    array: []Value,
    /// Table — ordered collection of key-value pairs.
    table: Table,

    /// Table (key-value entries, preserving source order).
    pub const Table = struct {
        /// Entries in source order. Slices (`key` and value's strings) point
        /// into the source text and/or arena-allocated memory.
        entries: []Entry,

        /// One key-value pair in a table.
        pub const Entry = struct {
            /// Key as written in source (without surrounding quotes for bare keys).
            key: []const u8,
            value: Value,
        };
    };
};

// ---------- Error set ----------

/// Errors that `parse()` may return. v0.1.0 doesn't include line/column
/// in errors (planned for v0.2.0).
pub const ParseError = error{
    /// Unexpected character or malformed structure.
    InvalidSyntax,
    /// String was not closed before EOF or newline (in single-line strings).
    UnterminatedString,
    /// A number literal couldn't be parsed (invalid digits, bad format).
    InvalidNumber,
    /// A datetime literal couldn't be parsed.
    InvalidDatetime,
    /// The same key was defined twice in the same table.
    DuplicateKey,
    /// A key (bare or quoted) was empty.
    EmptyKey,
    /// Arena allocation failed.
    OutOfMemory,
};

// ---------- Public API ----------

/// Parse a TOML document into a dynamic `Value` tree.
///
/// `source` is the full TOML text (typically a file's contents). `arena`
/// backs all dynamic allocations: table entry arrays, arrays of values,
/// and any value copies. The returned `Value` tree may also reference
/// slices into `source` directly (for string keys and unescaped string
/// values).
///
/// **Caller owns the arena.** When the arena is freed, the `Value` tree
/// becomes invalid.
///
/// The root of any valid TOML document is always a `Value.Table`. The
/// returned `Value` will be `Value{ .table = ... }`.
///
/// **v0.1.0 limitations:**
/// - Errors don't include line/column (planned v0.2.0)
/// - Integers are capped at `i64` (range check on parse)
/// - Datetime is returned as a string, not a structured type
///
/// Example:
/// ```
/// var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
/// defer arena.deinit();
/// const v = try toml.parse(arena.allocator(), "name = \"myapp\"");
/// const name = toml.getString(v.table, "name").?;  // "myapp"
/// ```
pub fn parse(arena: Allocator, source: []const u8) ParseError!Value {
    _ = arena;
    _ = source;
    // v0.1.0-dev: stub. Real impl in next session.
    return ParseError.InvalidSyntax; // distinct from error.Todo so error-path tests fail differently
}

// ---------- Accessor helpers ----------
//
// All accessors take `Value.Table` (by value, not pointer). The user
// passes `v.table` directly — no deref needed because the union variant
// stores `Table` by value, not by pointer.

/// Get a value from a table by key. Returns `null` if the key isn't in the table.
/// Use type-specific accessors (`getString`, `getInt`, etc.) to also check type.
pub fn get(t: Value.Table, key: []const u8) ?Value {
    for (t.entries) |e| {
        if (mem.eql(u8, e.key, key)) return e.value;
    }
    return null;
}

/// Get a `string` value. Returns `null` if key missing OR value is not a string.
pub fn getString(t: Value.Table, key: []const u8) ?[]const u8 {
    return switch (get(t, key) orelse return null) {
        .string => |s| s,
        else => null,
    };
}

/// Get an `integer` value. Returns `null` if missing or wrong type.
pub fn getInt(t: Value.Table, key: []const u8) ?i64 {
    return switch (get(t, key) orelse return null) {
        .integer => |n| n,
        else => null,
    };
}

/// Get a `float` value. Returns `null` if missing or wrong type.
pub fn getFloat(t: Value.Table, key: []const u8) ?f64 {
    return switch (get(t, key) orelse return null) {
        .float => |n| n,
        else => null,
    };
}

/// Get a `boolean` value. Returns `null` if missing or wrong type.
pub fn getBool(t: Value.Table, key: []const u8) ?bool {
    return switch (get(t, key) orelse return null) {
        .boolean => |b| b,
        else => null,
    };
}

/// Get a sub-table. Returns `null` if missing or wrong type.
/// The returned `Table` is by value (a copy of the struct, but the `entries`
/// slice inside still points to the same memory).
pub fn getTable(t: Value.Table, key: []const u8) ?Value.Table {
    return switch (get(t, key) orelse return null) {
        .table => |sub| sub,
        else => null,
    };
}

/// Get an array. Returns `null` if missing or wrong type.
pub fn getArray(t: Value.Table, key: []const u8) ?[]Value {
    return switch (get(t, key) orelse return null) {
        .array => |a| a,
        else => null,
    };
}

/// Walk a dotted path (e.g., `&.{"server", "host"}`) to a nested value.
/// Returns `null` if any segment is missing or if a non-table is encountered
/// partway through.
///
/// Example:
/// ```
/// const v = try toml.parse(arena, src);
/// const host = toml.getString(
///     toml.getPath(v, &.{"server", "host"}).?.table,
///     "default"
/// ).?;  // doesn't quite work, see helper below
/// ```
pub fn getPath(root: Value, path: []const []const u8) ?Value {
    var current = root;
    for (path) |segment| {
        const t = switch (current) {
            .table => |tbl| tbl,
            else => return null,
        };
        current = get(t, segment) orelse return null;
    }
    return current;
}

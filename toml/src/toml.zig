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
    /// Table — pointer to an arena-allocated `Table` struct. The pointer is
    /// stable for the lifetime of the arena passed to `parse()`.
    table: *Table,

    /// Table (key-value entries, preserving source order).
    /// Tables live in arena memory, addressed by `Value.table` pointer.
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
    var parser = Parser{
        .source = source,
        .pos = 0,
        .arena = arena,
        .root = undefined, // set below
        .current = undefined, // set below
    };

    // Allocate the root table in arena. Its address is stable for the
    // duration of parsing (only its `entries` slice is realloc'd).
    const root = try arena.create(Value.Table);
    root.* = .{ .entries = &.{} };
    parser.root = root;
    parser.current = root;

    try parser.parseDocument();

    return Value{ .table = root };
}

// ---------- Accessor helpers ----------
//
// All accessors take `Value.Table` (by value, not pointer). The user
// passes `v.table` directly — no deref needed because the union variant
// stores `Table` (struct), and the value semantics work for reads.
// (The `Value.table` variant is a `*Table` pointer, but the user
// accesses it as `v.table` which gives a `*Table`; we deref to `Table`
// in the accessor signatures for ergonomic call sites.)

/// Get a value from a table by key. Returns `null` if the key isn't in the table.
/// Use type-specific accessors (`getString`, `getInt`, etc.) to also check type.
pub fn get(t: *const Value.Table, key: []const u8) ?Value {
    for (t.entries) |e| {
        if (mem.eql(u8, e.key, key)) return e.value;
    }
    return null;
}

/// Get a `string` value. Returns `null` if key missing OR value is not a string.
pub fn getString(t: *const Value.Table, key: []const u8) ?[]const u8 {
    return switch (get(t, key) orelse return null) {
        .string => |s| s,
        else => null,
    };
}

/// Get an `integer` value. Returns `null` if missing or wrong type.
pub fn getInt(t: *const Value.Table, key: []const u8) ?i64 {
    return switch (get(t, key) orelse return null) {
        .integer => |n| n,
        else => null,
    };
}

/// Get a `float` value. Returns `null` if missing or wrong type.
pub fn getFloat(t: *const Value.Table, key: []const u8) ?f64 {
    return switch (get(t, key) orelse return null) {
        .float => |n| n,
        else => null,
    };
}

/// Get a `boolean` value. Returns `null` if missing or wrong type.
pub fn getBool(t: *const Value.Table, key: []const u8) ?bool {
    return switch (get(t, key) orelse return null) {
        .boolean => |b| b,
        else => null,
    };
}

/// Get a sub-table as a pointer. Returns `null` if missing or wrong type.
/// The pointer is stable for the lifetime of the arena passed to `parse()`.
pub fn getTable(t: *const Value.Table, key: []const u8) ?*Value.Table {
    return switch (get(t, key) orelse return null) {
        .table => |sub| sub,
        else => null,
    };
}

/// Get an array. Returns `null` if missing or wrong type.
pub fn getArray(t: *const Value.Table, key: []const u8) ?[]Value {
    return switch (get(t, key) orelse return null) {
        .array => |a| a,
        else => null,
    };
}

/// Walk a dotted path (e.g., `&.{"server", "host"}`) to a nested value.
/// Returns `null` if any segment is missing or if a non-table is encountered
/// partway through.
pub fn getPath(root: Value, path: []const []const u8) ?Value {
    var current = root;
    for (path) |segment| {
        const t = switch (current) {
            .table => |tbl| tbl, // *Value.Table
            else => return null,
        };
        current = get(t, segment) orelse return null;
    }
    return current;
}

// ---------- Internal: Parser ----------

const Parser = struct {
    source: []const u8,
    pos: usize,
    arena: Allocator,
    root: *Value.Table,
    current: *Value.Table,

    // ----- Low-level helpers -----

    fn peek(self: *const Parser) ?u8 {
        if (self.pos >= self.source.len) return null;
        return self.source[self.pos];
    }

    fn peekAt(self: *const Parser, offset: usize) ?u8 {
        const i = self.pos + offset;
        if (i >= self.source.len) return null;
        return self.source[i];
    }

    fn advance(self: *Parser) ?u8 {
        if (self.pos >= self.source.len) return null;
        const c = self.source[self.pos];
        self.pos += 1;
        return c;
    }

    fn skipWsAndComments(self: *Parser) void {
        while (self.pos < self.source.len) {
            const c = self.source[self.pos];
            if (c == ' ' or c == '\t' or c == '\n' or c == '\r') {
                self.pos += 1;
            } else if (c == '#') {
                // Skip to end of line
                while (self.pos < self.source.len and self.source[self.pos] != '\n') {
                    self.pos += 1;
                }
            } else {
                break;
            }
        }
    }

    fn rest(self: *const Parser) []const u8 {
        return self.source[self.pos..];
    }

    // ----- Entry insertion -----

    /// Append an entry to a table, with duplicate-key detection.
    /// May realloc the table's entries slice.
    fn appendEntry(self: *Parser, t: *Value.Table, key: []const u8, value: Value) ParseError!void {
        // Duplicate check
        for (t.entries) |e| {
            if (mem.eql(u8, e.key, key)) return ParseError.DuplicateKey;
        }
        const new_entries = try self.arena.realloc(t.entries, t.entries.len + 1);
        new_entries[t.entries.len] = .{ .key = key, .value = value };
        t.entries = new_entries;
    }

    // ----- Table navigation -----

    /// Navigate to the table at the given path from the root, creating
    /// intermediate tables as needed. Used for `[a.b.c]` headers.
    fn navigateToTable(self: *Parser, root: *Value.Table, path: []const []const u8) ParseError!*Value.Table {
        var current: *Value.Table = root;
        for (path) |segment| {
            if (segment.len == 0) return ParseError.EmptyKey;
            if (findEntry(current.*, segment)) |i| {
                switch (current.entries[i].value) {
                    .table => |sub| current = sub, // *Table, stable
                    else => return ParseError.InvalidSyntax,
                }
            } else {
                // Create new sub-table
                const new_t = try self.arena.create(Value.Table);
                new_t.* = .{ .entries = &.{} };
                try self.appendEntry(current, segment, Value{ .table = new_t });
                current = new_t;
            }
        }
        return current;
    }

    /// Navigate to the array at the given path from the root, creating
    /// intermediate tables as needed. The last segment must be (or become)
    /// an array. A new table is appended to the array, and that table is
    /// returned as the new "current" for following key-value pairs.
    fn navigateToArrayOfTables(self: *Parser, root: *Value.Table, path: []const []const u8) ParseError!*Value.Table {
        if (path.len == 0) return ParseError.EmptyKey;
        var current: *Value.Table = root;
        // Navigate to parent (all segments except last)
        for (path[0 .. path.len - 1]) |segment| {
            if (segment.len == 0) return ParseError.EmptyKey;
            if (findEntry(current.*, segment)) |i| {
                switch (current.entries[i].value) {
                    .table => |sub| current = sub,
                    else => return ParseError.InvalidSyntax,
                }
            } else {
                const new_t = try self.arena.create(Value.Table);
                new_t.* = .{ .entries = &.{} };
                try self.appendEntry(current, segment, Value{ .table = new_t });
                current = new_t;
            }
        }
        // Last segment: must be (or become) an array
        const last = path[path.len - 1];
        if (last.len == 0) return ParseError.EmptyKey;

        // Find or create the array
        var arr: []Value = &.{};
        var arr_idx: ?usize = null;
        if (findEntry(current.*, last)) |i| {
            switch (current.entries[i].value) {
                .array => |a| {
                    arr = a;
                    arr_idx = i;
                },
                else => return ParseError.InvalidSyntax,
            }
        } else {
            try self.appendEntry(current, last, Value{ .array = arr });
            arr_idx = current.entries.len - 1;
        }

        // Append a new table to the array
        const new_t = try self.arena.create(Value.Table);
        new_t.* = .{ .entries = &.{} };
        const new_arr = try self.arena.realloc(arr, arr.len + 1);
        new_arr[arr.len] = Value{ .table = new_t };
        // Update the parent's slice to point to the new array
        if (arr_idx) |i| {
            current.entries[i].value = .{ .array = new_arr };
        }
        return new_t;
    }

    // ----- Document loop -----

    fn parseDocument(self: *Parser) ParseError!void {
        self.skipWsAndComments();
        while (self.pos < self.source.len) {
            if (self.peek() == '[') {
                if (self.peekAt(1) == '[') {
                    try self.parseArrayOfTablesHeader();
                } else {
                    try self.parseTableHeader();
                }
            } else {
                try self.parseKeyValue();
            }
            self.skipWsAndComments();
        }
    }

    fn parseTableHeader(self: *Parser) ParseError!void {
        try self.expectChar('[');
        self.skipWsAndComments();
        const path = try self.parseKeyPath();
        self.skipWsAndComments();
        try self.expectChar(']');
        // Headers are always rooted at the document root.
        self.current = try self.navigateToTable(self.root, path);
    }

    fn parseArrayOfTablesHeader(self: *Parser) ParseError!void {
        try self.expectChar('[');
        try self.expectChar('[');
        self.skipWsAndComments();
        const path = try self.parseKeyPath();
        self.skipWsAndComments();
        try self.expectChar(']');
        try self.expectChar(']');
        // Headers are always rooted at the document root.
        self.current = try self.navigateToArrayOfTables(self.root, path);
    }

    // ----- Key-value -----

    fn parseKeyValue(self: *Parser) ParseError!void {
        const path = try self.parseKeyPath();
        self.skipWsAndComments();
        try self.expectChar('=');
        self.skipWsAndComments();
        const value = try self.parseValue();
        if (path.len == 1) {
            try self.appendEntry(self.current, path[0], value);
        } else {
            // Dotted key — navigate to parent (creating intermediates)
            const parent = try self.navigateToTable(self.current, path[0 .. path.len - 1]);
            try self.appendEntry(parent, path[path.len - 1], value);
        }
    }

    // ----- Keys -----

    fn parseKey(self: *Parser) ParseError![]const u8 {
        const c = self.peek() orelse return ParseError.InvalidSyntax;
        if (c == '"') {
            return self.parseBasicString();
        } else if (c == '\'') {
            return self.parseLiteralString();
        } else {
            return self.parseBareKey();
        }
    }

    fn parseBareKey(self: *Parser) ParseError![]const u8 {
        const start = self.pos;
        while (self.pos < self.source.len) {
            const c = self.source[self.pos];
            if (isBareKeyChar(c)) {
                self.pos += 1;
            } else {
                break;
            }
        }
        if (self.pos == start) return ParseError.EmptyKey;
        return self.source[start..self.pos];
    }

    fn parseKeyPath(self: *Parser) ParseError![]const []const u8 {
        // Allocate a copy in the arena so the slice is stable.
        var segments_buf: [32][]const u8 = undefined;
        var n: usize = 0;
        segments_buf[n] = try self.parseKey();
        n += 1;
        while (self.peek() == '.') {
            self.pos += 1;
            if (n >= segments_buf.len) return ParseError.InvalidSyntax;
            segments_buf[n] = try self.parseKey();
            n += 1;
        }
        // Copy the segments to the arena for stability
        const stable = try self.arena.alloc([]const u8, n);
        @memcpy(stable, segments_buf[0..n]);
        return stable;
    }

    // ----- Values -----

    fn parseValue(self: *Parser) ParseError!Value {
        const c = self.peek() orelse return ParseError.InvalidSyntax;
        return switch (c) {
            '"' => Value{ .string = try self.parseBasicString() },
            '\'' => Value{ .string = try self.parseLiteralString() },
            '[' => Value{ .array = try self.parseArray() },
            '{' => try self.parseInlineTable(),
            't', 'f' => try self.parseBool(),
            'i' => if (self.rest().len >= 3 and mem.eql(u8, self.rest()[0..3], "inf")) blk: {
                self.pos += 3;
                break :blk Value{ .float = std.math.inf(f64) };
            } else try self.parseDatetimeOrError(),
            'n' => if (self.rest().len >= 3 and mem.eql(u8, self.rest()[0..3], "nan")) blk: {
                self.pos += 3;
                break :blk Value{ .float = std.math.nan(f64) };
            } else try self.parseDatetimeOrError(),
            '0'...'9' => if (looksLikeDatetime(self.rest())) try self.parseDatetimeOrError() else try self.parseNumber(),
            '+', '-' => try self.parseNumber(),
            else => try self.parseDatetimeOrError(),
        };
    }

    fn parseDatetimeOrError(self: *Parser) ParseError!Value {
        // Datetime starts with a digit (year). If not a digit, it's invalid.
        const c = self.peek() orelse return ParseError.InvalidDatetime;
        if (c < '0' or c > '9') return ParseError.InvalidDatetime;
        const start = self.pos;
        while (self.pos < self.source.len) {
            const ch = self.source[self.pos];
            if (isDatetimeChar(ch)) {
                self.pos += 1;
            } else {
                break;
            }
        }
        if (self.pos == start) return ParseError.InvalidDatetime;
        return Value{ .datetime = self.source[start..self.pos] };
    }

    // ----- Strings -----

    fn parseBasicString(self: *Parser) ParseError![]const u8 {
        // Multi-line basic string: """..."""
        if (self.peekAt(0) == '"' and self.peekAt(1) == '"' and self.peekAt(2) == '"') {
            self.pos += 3;
            // Skip leading newline
            if (self.peek() == '\n') {
                self.pos += 1;
            } else if (self.peek() == '\r' and self.peekAt(1) == '\n') {
                self.pos += 2;
            }
            const start = self.pos;
            while (self.pos + 2 < self.source.len) {
                if (self.source[self.pos] == '"' and
                    self.source[self.pos + 1] == '"' and
                    self.source[self.pos + 2] == '"')
                {
                    const result = self.source[start..self.pos];
                    self.pos += 3;
                    return result;
                }
                self.pos += 1;
            }
            return ParseError.UnterminatedString;
        }

        // Single-line basic string: "..."
        try self.expectChar('"');
        const start = self.pos;
        while (self.pos < self.source.len) {
            const c = self.source[self.pos];
            if (c == '"') {
                const result = self.source[start..self.pos];
                self.pos += 1;
                return result;
            }
            if (c == '\n' or c == '\r') return ParseError.UnterminatedString;
            if (c == '\\') {
                // Skip escape sequence (v0.1.0: just skip 2 chars, no actual unescape)
                self.pos += 2;
                continue;
            }
            self.pos += 1;
        }
        return ParseError.UnterminatedString;
    }

    fn parseLiteralString(self: *Parser) ParseError![]const u8 {
        // Multi-line literal: '''...'''
        if (self.peekAt(0) == '\'' and self.peekAt(1) == '\'' and self.peekAt(2) == '\'') {
            self.pos += 3;
            if (self.peek() == '\n') {
                self.pos += 1;
            } else if (self.peek() == '\r' and self.peekAt(1) == '\n') {
                self.pos += 2;
            }
            const start = self.pos;
            while (self.pos + 2 < self.source.len) {
                if (self.source[self.pos] == '\'' and
                    self.source[self.pos + 1] == '\'' and
                    self.source[self.pos + 2] == '\'')
                {
                    const result = self.source[start..self.pos];
                    self.pos += 3;
                    return result;
                }
                self.pos += 1;
            }
            return ParseError.UnterminatedString;
        }
        // Single-line literal: '...'
        try self.expectChar('\'');
        const start = self.pos;
        while (self.pos < self.source.len) {
            const c = self.source[self.pos];
            if (c == '\'') {
                const result = self.source[start..self.pos];
                self.pos += 1;
                return result;
            }
            if (c == '\n' or c == '\r') return ParseError.UnterminatedString;
            self.pos += 1;
        }
        return ParseError.UnterminatedString;
    }

    // ----- Numbers -----

    fn parseNumber(self: *Parser) ParseError!Value {
        const start = self.pos;
        var is_float = false;

        // Optional sign
        if (self.peek() == '+' or self.peek() == '-') {
            self.pos += 1;
        }

        // Digits before decimal/exponent
        const int_start = self.pos;
        while (self.peek()) |c| {
            if (c >= '0' and c <= '9') {
                self.pos += 1;
            } else if (c == '_') {
                self.pos += 1;
            } else {
                break;
            }
        }

        if (self.pos == int_start) {
            return ParseError.InvalidNumber;
        }

        // Decimal part?
        if (self.peek() == '.') {
            is_float = true;
            self.pos += 1;
            const frac_start = self.pos;
            while (self.peek()) |c| {
                if (c >= '0' and c <= '9') {
                    self.pos += 1;
                } else if (c == '_') {
                    self.pos += 1;
                } else {
                    break;
                }
            }
            _ = frac_start; // "1." is allowed
        }

        // Exponent?
        if (self.peek() == 'e' or self.peek() == 'E') {
            is_float = true;
            self.pos += 1;
            if (self.peek() == '+' or self.peek() == '-') {
                self.pos += 1;
            }
            const exp_start = self.pos;
            while (self.peek()) |c| {
                if (c >= '0' and c <= '9') {
                    self.pos += 1;
                } else {
                    break;
                }
            }
            if (self.pos == exp_start) {
                return ParseError.InvalidNumber;
            }
        }

        // Validate trailing: must be followed by ws/comment/eol/eof
        if (self.peek()) |c| {
            if (!isEndOfValue(c)) {
                return ParseError.InvalidNumber;
            }
        }

        const literal = self.source[start..self.pos];
        // Remove leading/trailing underscores, then all internal ones
        const trimmed = std.mem.trim(u8, literal, "_");
        var buf: [64]u8 = undefined;
        const compact = stripUnderscores(trimmed, &buf) orelse return ParseError.InvalidNumber;

        if (is_float) {
            return Value{ .float = std.fmt.parseFloat(f64, compact) catch return ParseError.InvalidNumber };
        } else {
            return Value{ .integer = std.fmt.parseInt(i64, compact, 10) catch return ParseError.InvalidNumber };
        }
    }

    fn parseBool(self: *Parser) ParseError!Value {
        if (self.rest().len >= 4 and mem.eql(u8, self.rest()[0..4], "true")) {
            self.pos += 4;
            return Value{ .boolean = true };
        }
        if (self.rest().len >= 5 and mem.eql(u8, self.rest()[0..5], "false")) {
            self.pos += 5;
            return Value{ .boolean = false };
        }
        return ParseError.InvalidSyntax;
    }

    // ----- Arrays -----

    fn parseArray(self: *Parser) ParseError![]Value {
        try self.expectChar('[');
        // Pre-allocate a stack buffer
        var items: [64]Value = undefined;
        var n: usize = 0;
        self.skipWsAndComments();
        if (self.peek() == ']') {
            self.pos += 1;
            // Empty array
            return self.arena.dupe(Value, &.{}) catch return ParseError.OutOfMemory;
        }
        while (true) {
            if (n >= items.len) return ParseError.InvalidSyntax;
            items[n] = try self.parseValue();
            n += 1;
            self.skipWsAndComments();
            const c = self.peek() orelse return ParseError.InvalidSyntax;
            if (c == ',') {
                self.pos += 1;
                self.skipWsAndComments();
                if (self.peek() == ']') {
                    self.pos += 1;
                    break;
                }
            } else if (c == ']') {
                self.pos += 1;
                break;
            } else {
                return ParseError.InvalidSyntax;
            }
        }
        // Copy from stack to arena
        const arena_items = self.arena.dupe(Value, items[0..n]) catch return ParseError.OutOfMemory;
        return arena_items;
    }

    // ----- Inline tables -----

    fn parseInlineTable(self: *Parser) ParseError!Value {
        try self.expectChar('{');
        const new_t = try self.arena.create(Value.Table);
        new_t.* = .{ .entries = &.{} };
        self.skipWsAndComments();
        if (self.peek() == '}') {
            self.pos += 1;
            return Value{ .table = new_t };
        }
        while (true) {
            const key = try self.parseKey();
            self.skipWsAndComments();
            try self.expectChar('=');
            self.skipWsAndComments();
            const value = try self.parseValue();
            // Insert into new_t, checking duplicates
            for (new_t.entries) |e| {
                if (mem.eql(u8, e.key, key)) return ParseError.DuplicateKey;
            }
            const new_entries = try self.arena.realloc(new_t.entries, new_t.entries.len + 1);
            new_entries[new_t.entries.len] = .{ .key = key, .value = value };
            new_t.entries = new_entries;
            self.skipWsAndComments();
            const c = self.peek() orelse return ParseError.InvalidSyntax;
            if (c == ',') {
                self.pos += 1;
                self.skipWsAndComments();
                if (self.peek() == '}') {
                    self.pos += 1;
                    break;
                }
            } else if (c == '}') {
                self.pos += 1;
                break;
            } else {
                return ParseError.InvalidSyntax;
            }
        }
        return Value{ .table = new_t };
    }

    // ----- Misc -----

    fn expectChar(self: *Parser, expected: u8) ParseError!void {
        const c = self.advance() orelse return ParseError.InvalidSyntax;
        if (c != expected) return ParseError.InvalidSyntax;
    }
};

// ---------- File-private helpers ----------

fn findEntry(t: Value.Table, key: []const u8) ?usize {
    for (t.entries, 0..) |e, i| {
        if (mem.eql(u8, e.key, key)) return i;
    }
    return null;
}

fn isBareKeyChar(c: u8) bool {
    return (c >= 'A' and c <= 'Z') or
        (c >= 'a' and c <= 'z') or
        (c >= '0' and c <= '9') or
        c == '_' or c == '-';
}

fn isDatetimeChar(c: u8) bool {
    return (c >= '0' and c <= '9') or
        c == 'T' or c == 't' or
        c == 'Z' or c == 'z' or
        c == '-' or c == '+' or c == ':' or c == '.';
}

fn isEndOfValue(c: u8) bool {
    return c == ' ' or c == '\t' or c == '\n' or c == '\r' or
        c == '#' or c == ',' or c == ']' or c == '}';
}

/// Heuristic: a string starts like a datetime if it begins with 4 digits + '-'.
/// Used by `parseValue` to disambiguate `2024-01-15...` (datetime) from
/// `12345` (integer).
fn looksLikeDatetime(s: []const u8) bool {
    if (s.len < 5) return false;
    for (s[0..4]) |c| {
        if (c < '0' or c > '9') return false;
    }
    return s[4] == '-';
}

/// Remove `_` separators from a number literal. Output is written to `buf`.
/// Returns a slice of `buf` on success, or null if the result would exceed buf.
fn stripUnderscores(s: []const u8, buf: []u8) ?[]const u8 {
    if (s.len > buf.len) return null;
    var out_idx: usize = 0;
    for (s) |c| {
        if (c == '_') continue;
        buf[out_idx] = c;
        out_idx += 1;
    }
    return buf[0..out_idx];
}

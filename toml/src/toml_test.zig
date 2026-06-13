//! RED tests for `toml` parser.
//! All tests in this file are expected to FAIL until the impl lands.
//! Run: `cd toml && zig build test` (after fingerprint is set).

const std = @import("std");
const testing = std.testing;
const toml = @import("toml.zig");

// Helper: parse with a real arena so tests don't leak
fn parseSource(comptime src: []const u8) !toml.Value {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    return toml.parse(arena.allocator(), src);
}

// ---------- Basic value types ----------

test "empty source → empty root table" {
    const v = try parseSource("");
    try testing.expectEqual(@as(usize, 0), v.table.entries.len);
}

test "simple string value" {
    const v = try parseSource("name = \"hello\"");
    try testing.expectEqualStrings("hello", toml.getString(v.table, "name").?);
}

test "literal string (single quotes, no escaping)" {
    const v = try parseSource("path = 'C:\\Users'");
    try testing.expectEqualStrings("C:\\Users", toml.getString(v.table, "path").?);
}

test "positive integer" {
    const v = try parseSource("n = 42");
    try testing.expectEqual(@as(i64, 42), toml.getInt(v.table, "n").?);
}

test "negative integer" {
    const v = try parseSource("n = -17");
    try testing.expectEqual(@as(i64, -17), toml.getInt(v.table, "n").?);
}

test "integer with underscore separator" {
    const v = try parseSource("n = 1_000_000");
    try testing.expectEqual(@as(i64, 1_000_000), toml.getInt(v.table, "n").?);
}

test "float basic" {
    const v = try parseSource("pi = 3.14");
    try testing.expectEqual(@as(f64, 3.14), toml.getFloat(v.table, "pi").?);
}

test "float scientific notation" {
    const v = try parseSource("x = 1.5e10");
    try testing.expectEqual(@as(f64, 1.5e10), toml.getFloat(v.table, "x").?);
}

test "boolean true" {
    const v = try parseSource("on = true");
    try testing.expectEqual(true, toml.getBool(v.table, "on").?);
}

test "boolean false" {
    const v = try parseSource("off = false");
    try testing.expectEqual(false, toml.getBool(v.table, "off").?);
}

test "datetime stored as string" {
    // v0.1.0: datetime is a string. v0.2.0 will have a separate type.
    const v = try parseSource("ts = 2024-01-15T10:30:00Z");
    try testing.expectEqualStrings("2024-01-15T10:30:00Z", toml.getString(v.table, "ts").?);
}

// ---------- Arrays ----------

test "array of integers" {
    const v = try parseSource("nums = [1, 2, 3]");
    const arr = toml.getArray(v.table, "nums").?;
    try testing.expectEqual(@as(usize, 3), arr.len);
    try testing.expectEqual(@as(i64, 1), arr[0].integer);
    try testing.expectEqual(@as(i64, 2), arr[1].integer);
    try testing.expectEqual(@as(i64, 3), arr[2].integer);
}

test "array of mixed types" {
    const v = try parseSource("vals = [1, \"two\", 3.0]");
    const arr = toml.getArray(v.table, "vals").?;
    try testing.expectEqual(@as(usize, 3), arr.len);
    try testing.expectEqual(@as(i64, 1), arr[0].integer);
    try testing.expectEqualStrings("two", arr[1].string);
    try testing.expectEqual(@as(f64, 3.0), arr[2].float);
}

test "multiline array" {
    const v = try parseSource("vals = [\n  1,\n  2,\n  3,\n]");
    const arr = toml.getArray(v.table, "vals").?;
    try testing.expectEqual(@as(usize, 3), arr.len);
    try testing.expectEqual(@as(i64, 1), arr[0].integer);
    try testing.expectEqual(@as(i64, 3), arr[2].integer);
}

// ---------- Tables ----------

test "regular table" {
    const v = try parseSource("[server]\nhost = \"localhost\"\nport = 8080");
    const server = toml.getTable(v.table, "server").?;
    try testing.expectEqualStrings("localhost", toml.getString(server, "host").?);
    try testing.expectEqual(@as(i64, 8080), toml.getInt(server, "port").?);
}

test "nested tables via dotted keys" {
    const v = try parseSource("physical.color = \"red\"\nphysical.shape = \"round\"");
    const phys = toml.getTable(v.table, "physical").?;
    try testing.expectEqualStrings("red", toml.getString(phys, "color").?);
    try testing.expectEqualStrings("round", toml.getString(phys, "shape").?);
}

test "inline table" {
    const v = try parseSource("point = { x = 1, y = 2 }");
    const pt = toml.getTable(v.table, "point").?;
    try testing.expectEqual(@as(i64, 1), toml.getInt(pt, "x").?);
    try testing.expectEqual(@as(i64, 2), toml.getInt(pt, "y").?);
}

test "array of tables" {
    const v = try parseSource("[[fruits]]\nname = \"apple\"\n\n[[fruits]]\nname = \"banana\"");
    const arr = toml.getArray(v.table, "fruits").?;
    try testing.expectEqual(@as(usize, 2), arr.len);
    const first = arr[0].table;
    try testing.expectEqualStrings("apple", toml.getString(first, "name").?);
    const second = arr[1].table;
    try testing.expectEqualStrings("banana", toml.getString(second, "name").?);
}

test "getPath walks nested dotted keys" {
    const v = try parseSource("[server]\nhost = \"localhost\"");
    const host = toml.getPath(v, &.{ "server", "host" }).?;
    try testing.expectEqualStrings("localhost", host.string);
}

test "comments are ignored" {
    const v = try parseSource("# this is a comment\nname = \"myapp\"  # inline comment");
    try testing.expectEqualStrings("myapp", toml.getString(v.table, "name").?);
}

// ---------- Error cases ----------

test "error on duplicate key in same table" {
    const src = "name = \"a\"\nname = \"b\"";
    try testing.expectError(toml.ParseError.DuplicateKey, toml.parse(testing.allocator, src));
}

test "error on unterminated string" {
    try testing.expectError(toml.ParseError.UnterminatedString, toml.parse(testing.allocator, "name = \"hello"));
}

test "error on invalid number" {
    try testing.expectError(toml.ParseError.InvalidNumber, toml.parse(testing.allocator, "n = 12abc"));
}

test "error on empty key" {
    try testing.expectError(toml.ParseError.EmptyKey, toml.parse(testing.allocator, " = 1"));
}

//! Tests for `toml` parser.
//! All tests should be GREEN now (impl is in src/toml.zig).

const std = @import("std");
const testing = std.testing;
const toml = @import("toml.zig");

// ---------- Basic value types ----------

test "empty source → empty root table" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const v = try toml.parse(arena.allocator(), "");
    try testing.expectEqual(@as(usize, 0), v.table.entries.len);
}

test "simple string value" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const v = try toml.parse(arena.allocator(), "name = \"hello\"");
    try testing.expectEqualStrings("hello", toml.getString(v.table, "name").?);
}

test "literal string (single quotes, no escaping)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const v = try toml.parse(arena.allocator(), "path = 'C:\\Users'");
    try testing.expectEqualStrings("C:\\Users", toml.getString(v.table, "path").?);
}

test "positive integer" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const v = try toml.parse(arena.allocator(), "n = 42");
    try testing.expectEqual(@as(i64, 42), toml.getInt(v.table, "n").?);
}

test "negative integer" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const v = try toml.parse(arena.allocator(), "n = -17");
    try testing.expectEqual(@as(i64, -17), toml.getInt(v.table, "n").?);
}

test "integer with underscore separator" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const v = try toml.parse(arena.allocator(), "n = 1_000_000");
    try testing.expectEqual(@as(i64, 1_000_000), toml.getInt(v.table, "n").?);
}

test "float basic" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const v = try toml.parse(arena.allocator(), "pi = 3.14");
    try testing.expectEqual(@as(f64, 3.14), toml.getFloat(v.table, "pi").?);
}

test "float scientific notation" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const v = try toml.parse(arena.allocator(), "x = 1.5e10");
    try testing.expectEqual(@as(f64, 1.5e10), toml.getFloat(v.table, "x").?);
}

test "boolean true" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const v = try toml.parse(arena.allocator(), "on = true");
    try testing.expectEqual(true, toml.getBool(v.table, "on").?);
}

test "boolean false" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const v = try toml.parse(arena.allocator(), "off = false");
    try testing.expectEqual(false, toml.getBool(v.table, "off").?);
}

test "datetime stored as string" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const v = try toml.parse(arena.allocator(), "ts = 2024-01-15T10:30:00Z");
    // v0.1.0: datetime is stored as the `.datetime` variant, not `.string`.
    // v0.2.0 will add a `getDatetime` accessor.
    const ts_val = toml.get(v.table, "ts").?;
    try testing.expectEqualStrings("2024-01-15T10:30:00Z", ts_val.datetime);
}

// ---------- Arrays ----------

test "array of integers" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const v = try toml.parse(arena.allocator(), "nums = [1, 2, 3]");
    const arr = toml.getArray(v.table, "nums").?;
    try testing.expectEqual(@as(usize, 3), arr.len);
    try testing.expectEqual(@as(i64, 1), arr[0].integer);
    try testing.expectEqual(@as(i64, 2), arr[1].integer);
    try testing.expectEqual(@as(i64, 3), arr[2].integer);
}

test "array of mixed types" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const v = try toml.parse(arena.allocator(), "vals = [1, \"two\", 3.0]");
    const arr = toml.getArray(v.table, "vals").?;
    try testing.expectEqual(@as(usize, 3), arr.len);
    try testing.expectEqual(@as(i64, 1), arr[0].integer);
    try testing.expectEqualStrings("two", arr[1].string);
    try testing.expectEqual(@as(f64, 3.0), arr[2].float);
}

test "multiline array" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const v = try toml.parse(arena.allocator(), "vals = [\n  1,\n  2,\n  3,\n]");
    const arr = toml.getArray(v.table, "vals").?;
    try testing.expectEqual(@as(usize, 3), arr.len);
    try testing.expectEqual(@as(i64, 1), arr[0].integer);
    try testing.expectEqual(@as(i64, 3), arr[2].integer);
}

// ---------- Tables ----------

test "regular table" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const v = try toml.parse(arena.allocator(), "[server]\nhost = \"localhost\"\nport = 8080");
    const server = toml.getTable(v.table, "server").?;
    try testing.expectEqualStrings("localhost", toml.getString(server, "host").?);
    try testing.expectEqual(@as(i64, 8080), toml.getInt(server, "port").?);
}

test "nested tables via dotted keys" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const v = try toml.parse(arena.allocator(), "physical.color = \"red\"\nphysical.shape = \"round\"");
    const phys = toml.getTable(v.table, "physical").?;
    try testing.expectEqualStrings("red", toml.getString(phys, "color").?);
    try testing.expectEqualStrings("round", toml.getString(phys, "shape").?);
}

test "inline table" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const v = try toml.parse(arena.allocator(), "point = { x = 1, y = 2 }");
    const pt = toml.getTable(v.table, "point").?;
    try testing.expectEqual(@as(i64, 1), toml.getInt(pt, "x").?);
    try testing.expectEqual(@as(i64, 2), toml.getInt(pt, "y").?);
}

test "array of tables" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const v = try toml.parse(arena.allocator(), "[[fruits]]\nname = \"apple\"\n\n[[fruits]]\nname = \"banana\"");
    const arr = toml.getArray(v.table, "fruits").?;
    try testing.expectEqual(@as(usize, 2), arr.len);
    const first = arr[0].table;
    try testing.expectEqualStrings("apple", toml.getString(first, "name").?);
    const second = arr[1].table;
    try testing.expectEqualStrings("banana", toml.getString(second, "name").?);
}

test "getPath walks nested dotted keys" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const v = try toml.parse(arena.allocator(), "[server]\nhost = \"localhost\"");
    const host = toml.getPath(v, &.{ "server", "host" }).?;
    try testing.expectEqualStrings("localhost", host.string);
}

test "comments are ignored" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const v = try toml.parse(arena.allocator(), "# this is a comment\nname = \"myapp\"  # inline comment");
    try testing.expectEqualStrings("myapp", toml.getString(v.table, "name").?);
}

// ---------- Error cases ----------

test "error on duplicate key in same table" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const src = "name = \"a\"\nname = \"b\"";
    try testing.expectError(toml.ParseError.DuplicateKey, toml.parse(arena.allocator(), src));
}

test "error on unterminated string" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    try testing.expectError(toml.ParseError.UnterminatedString, toml.parse(arena.allocator(), "name = \"hello"));
}

test "error on invalid number" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    try testing.expectError(toml.ParseError.InvalidNumber, toml.parse(arena.allocator(), "n = 12abc"));
}

test "error on empty key" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    try testing.expectError(toml.ParseError.EmptyKey, toml.parse(arena.allocator(), " = 1"));
}

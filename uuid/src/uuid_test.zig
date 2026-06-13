const std = @import("std");
const testing = std.testing;
const Uuid = @import("uuid.zig").Uuid;
const Version = @import("uuid.zig").Version;

test "v4: version bits = 0100 in byte 6" {
    var prng = std.Random.DefaultPrng.init(42);
    const id = Uuid.v4(prng.random());
    try testing.expectEqual(@as(u8, 0x40), id.bytes[6] & 0xf0);
}

test "v4: variant bits = 10 in byte 8" {
    var prng = std.Random.DefaultPrng.init(42);
    const id = Uuid.v4(prng.random());
    try testing.expectEqual(@as(u8, 0x80), id.bytes[8] & 0xc0);
}

test "v4: two calls produce different UUIDs" {
    var prng = std.Random.DefaultPrng.init(0);
    const a = Uuid.v4(prng.random());
    const b = Uuid.v4(prng.random());
    try testing.expect(!std.mem.eql(u8, &a.bytes, &b.bytes));
}

test "v4: 1000 calls all unique" {
    var prng = std.Random.DefaultPrng.init(123);
    var seen: [1000]Uuid = undefined;
    for (seen[0..]) |*slot| slot.* = Uuid.v4(prng.random());
    for (seen[0..], 0..) |a, i| {
        for (seen[i + 1 ..]) |b| {
            if (std.mem.eql(u8, &a.bytes, &b.bytes)) {
                return error.DuplicateUuid;
            }
        }
    }
}

test "v7At: version bits = 0111 in byte 6" {
    var prng = std.Random.DefaultPrng.init(42);
    const id = Uuid.v7At(prng.random(), 0);
    try testing.expectEqual(@as(u8, 0x70), id.bytes[6] & 0xf0);
}

test "v7At: variant bits = 10 in byte 8" {
    var prng = std.Random.DefaultPrng.init(42);
    const id = Uuid.v7At(prng.random(), 0);
    try testing.expectEqual(@as(u8, 0x80), id.bytes[8] & 0xc0);
}

test "v7At: timestamp occupies first 48 bits big-endian" {
    var prng = std.Random.DefaultPrng.init(42);
    const ts: u64 = 0x0123_4567_89ab;
    const id = Uuid.v7At(prng.random(), ts);
    const got = std.mem.readInt(u48, id.bytes[0..6], .big);
    try testing.expectEqual(@as(u48, ts), got);
}

test "v7At: two calls with same timestamp differ in random part" {
    var prng = std.Random.DefaultPrng.init(99);
    const ts: u64 = 0x0123_4567_89ab;
    const a = Uuid.v7At(prng.random(), ts);
    const b = Uuid.v7At(prng.random(), ts);
    // Timestamp bytes 0..6 should match
    try testing.expectEqualSlices(u8, a.bytes[0..6], b.bytes[0..6]);
    // Random bytes 6..16 should differ
    try testing.expect(!std.mem.eql(u8, a.bytes[6..], b.bytes[6..]));
}

test "version() reads byte 6 high nibble" {
    const v4_id = Uuid{ .bytes = .{ 0, 0, 0, 0, 0, 0, 0x40, 0, 0, 0, 0, 0, 0, 0, 0, 0 } };
    const v7_id = Uuid{ .bytes = .{ 0, 0, 0, 0, 0, 0, 0x70, 0, 0, 0, 0, 0, 0, 0, 0, 0 } };
    try testing.expectEqual(Version.v4, v4_id.version());
    try testing.expectEqual(Version.v7, v7_id.version());
}

test "isRfc4122: detects 10xx range" {
    const ok_lo = Uuid{ .bytes = .{ 0, 0, 0, 0, 0, 0, 0, 0, 0x80, 0, 0, 0, 0, 0, 0, 0 } };
    const ok_hi = Uuid{ .bytes = .{ 0, 0, 0, 0, 0, 0, 0, 0, 0xbf, 0, 0, 0, 0, 0, 0, 0 } };
    const not_ok = Uuid{ .bytes = .{ 0, 0, 0, 0, 0, 0, 0, 0, 0xc0, 0, 0, 0, 0, 0, 0, 0 } };
    try testing.expect(ok_lo.isRfc4122());
    try testing.expect(ok_hi.isRfc4122());
    try testing.expect(!not_ok.isRfc4122());
}

// ---------- parse / format tests ----------

test "parse: accepts canonical 8-4-4-4-12 lowercase" {
    // version=7, variant=10xx (byte 8 high nibble = 8)
    const s = "12345678-9abc-7ef0-8234-56789abcdef0";
    const id = try Uuid.parse(s);
    const expected = [_]u8{ 0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0x7e, 0xf0, 0x82, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0xde, 0xf0 };
    try testing.expectEqualSlices(u8, &expected, &id.bytes);
}

test "parse: accepts canonical uppercase" {
    const s = "12345678-9ABC-7EF0-8234-56789ABCDEF0";
    const id = try Uuid.parse(s);
    const expected = [_]u8{ 0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0x7e, 0xf0, 0x82, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0xde, 0xf0 };
    try testing.expectEqualSlices(u8, &expected, &id.bytes);
}

test "parse: accepts 32-char non-hyphenated form" {
    const s = "123456789abc7ef0823456789abcdef0";
    const id = try Uuid.parse(s);
    const expected = [_]u8{ 0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0x7e, 0xf0, 0x82, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0xde, 0xf0 };
    try testing.expectEqualSlices(u8, &expected, &id.bytes);
}

test "parse: rejects wrong length" {
    try testing.expectError(Uuid.ParseError.InvalidLength, Uuid.parse("abc"));
    try testing.expectError(Uuid.ParseError.InvalidLength, Uuid.parse("12345678-9abc-def0-1234-56789abcdef0-extra"));
    try testing.expectError(Uuid.ParseError.InvalidLength, Uuid.parse(""));
}

test "parse: rejects wrong hyphen positions" {
    // Hyphens at 8, 13, 18, 23 only — using version=4, variant=10xx (8234-)
    try testing.expectError(Uuid.ParseError.InvalidLength, Uuid.parse("1234567-89abc-4ef0-8234-56789abcdef0")); // wrong first hyphen
    try testing.expectError(Uuid.ParseError.InvalidLength, Uuid.parse("12345678-9abc04ef0-8234-56789abcdef0")); // missing hyphen
    try testing.expectError(Uuid.ParseError.InvalidLength, Uuid.parse("12345678X9abcX4ef0X8234X56789abcdef0")); // all X
}

test "parse: rejects non-hex characters" {
    try testing.expectError(Uuid.ParseError.InvalidHex, Uuid.parse("12345678-9abc-7ef0-8234-56789abcdefg"));
    try testing.expectError(Uuid.ParseError.InvalidHex, Uuid.parse("zzzzzzzz-zzzz-zzzz-zzzz-zzzzzzzzzzzz"));
}

test "parse: rejects invalid version (0, 2, 9-F)" {
    // version 0 (byte 6 = 0x0e)
    try testing.expectError(Uuid.ParseError.InvalidVersion, Uuid.parse("00000000-0abc-0ef0-8234-56789abcdef0"));
    // version 2 (byte 6 = 0x2e)
    try testing.expectError(Uuid.ParseError.InvalidVersion, Uuid.parse("20000000-9abc-2ef0-8234-56789abcdef0"));
    // version 9 (byte 6 = 0x9e)
    try testing.expectError(Uuid.ParseError.InvalidVersion, Uuid.parse("90000000-9abc-9ef0-8234-56789abcdef0"));
    // version F (byte 6 = 0xfe)
    try testing.expectError(Uuid.ParseError.InvalidVersion, Uuid.parse("f0000000-9abc-fef0-8234-56789abcdef0"));
}

test "parse: accepts valid versions 1, 3, 4, 5, 6, 7, 8" {
    // All use variant=10xx (8234-)
    _ = try Uuid.parse("11111111-9abc-1ef0-8234-56789abcdef0"); // v1
    _ = try Uuid.parse("31111111-9abc-3ef0-8234-56789abcdef0"); // v3
    _ = try Uuid.parse("41111111-9abc-4ef0-8234-56789abcdef0"); // v4
    _ = try Uuid.parse("51111111-9abc-5ef0-8234-56789abcdef0"); // v5
    _ = try Uuid.parse("61111111-9abc-6ef0-8234-56789abcdef0"); // v6
    _ = try Uuid.parse("71111111-9abc-7ef0-8234-56789abcdef0"); // v7
    _ = try Uuid.parse("81111111-9abc-8ef0-8234-56789abcdef0"); // v8
}

test "parse: rejects invalid variant (not 10xx)" {
    // 00xx (NCS reserved) — version=4, variant=00xx
    try testing.expectError(Uuid.ParseError.InvalidVariant, Uuid.parse("11111111-9abc-4ef0-0234-56789abcdef0"));
    // 11xx (Microsoft reserved) — version=4, variant=11xx
    try testing.expectError(Uuid.ParseError.InvalidVariant, Uuid.parse("11111111-9abc-4ef0-c234-56789abcdef0"));
    // 01xx (not defined) — version=4, variant=01xx
    try testing.expectError(Uuid.ParseError.InvalidVariant, Uuid.parse("11111111-9abc-4ef0-4234-56789abcdef0"));
}

test "format: produces 36-char canonical lowercase string" {
    // byte 8 = 0x82 → variant 10xx
    const id = Uuid{ .bytes = .{ 0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0x7e, 0xf0, 0x82, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0xde, 0xf0 } };
    var buf: [36]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    try id.format(&w);
    try testing.expectEqualStrings("12345678-9abc-7ef0-8234-56789abcdef0", &buf);
}

test "format: roundtrips through parse" {
    var prng = std.Random.DefaultPrng.init(0xdeadbeef);
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        const id = Uuid.v4(prng.random());
        var buf: [36]u8 = undefined;
        var w: std.Io.Writer = .fixed(&buf);
        try id.format(&w);
        const parsed = try Uuid.parse(&buf);
        try testing.expectEqualSlices(u8, &id.bytes, &parsed.bytes);
    }
}

test "format: v7At roundtrips through parse" {
    var prng = std.Random.DefaultPrng.init(0xcafebabe);
    const ts: u64 = 0x0123_4567_89ab;
    const id = Uuid.v7At(prng.random(), ts);
    var buf: [36]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    try id.format(&w);
    const parsed = try Uuid.parse(&buf);
    try testing.expectEqualSlices(u8, &id.bytes, &parsed.bytes);
    // version() should also work — v7 was set by v7At
    try testing.expectEqual(Version.v7, parsed.version());
}

test "format: zero UUID is a valid RFC4122 UUID (variant=0 is rejected by parse — use the nil UUID explicitly when needed)" {
    // byte 8 = 0x00 → variant 00xx (NCS) — NOT valid RFC 4122.
    // The all-zero UUID is historically "nil" but technically not RFC 4122.
    // Our format() prints it as-is; parse() would reject it.
    const id = Uuid{ .bytes = .{0} ** 16 };
    var buf: [36]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    try id.format(&w);
    try testing.expectEqualStrings("00000000-0000-0000-0000-000000000000", &buf);
}

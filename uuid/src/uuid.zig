//! UUID v4 (random) and v7 (time-ordered) per RFC 4122 / RFC 9562.
//!
//! Scope:
//!   - v4: random UUID
//!   - v7: time-ordered random UUID (sortable, preferred for new systems)
//!   - parse / format in canonical 8-4-4-4-12 form
//!   - accessors: `version()`, `isRfc4122()`
//!
//! Out of scope (deliberately):
//!   - v1, v3, v5, v6, v8 (not widely needed; add only if a real use case appears)
//!   - non-canonical string formats (Microsoft brace form, urn:uuid: prefix)
//!   - database-specific types (use [16]u8 directly; don't add a `Uuid` SQL wrapper)
//!   - namespace/MAC/MD5/SHA1 (those are v3/v5 only — out of scope)
//!
//! Stability: API frozen at 0.1.0. New versions = new functions, never signature changes.

const std = @import("std");
const Random = std.Random;
const mem = std.mem;

pub const Version = enum(u4) {
    v1 = 1,
    v4 = 4,
    v7 = 7,
};

/// 16-byte UUID. `bytes` is in big-endian for the typed fields.
pub const Uuid = extern struct {
    bytes: [16]u8,

    // ---------- Constructors ----------

    /// Random v4 UUID. Requires a CSPRNG; use `std.crypto.random` for that.
    /// Caller-provided Random keeps the function pure + explicit (no hidden state).
    pub fn v4(r: Random) Uuid {
        var self: Uuid = .{ .bytes = undefined };
        r.bytes(&self.bytes);
        // Version 4 → byte 6 high nibble = 0100
        self.bytes[6] = (self.bytes[6] & 0x0f) | 0x40;
        // Variant RFC4122 → byte 8 high two bits = 10
        self.bytes[8] = (self.bytes[8] & 0x3f) | 0x80;
        return self;
    }

    /// v7 UUID with explicit timestamp (ms since unix epoch).
    /// `ts_ms = 0` means "epoch start". Post-10889 AD would overflow 48 bits.
    /// Caller-provided timestamp keeps the function explicit + clock-agnostic
    /// (in Zig 0.16, `std.time.milliTimestamp` is gone — use `Io.Clock.now` or
    /// `std.posix.clock_gettime` at the call site and pass the value here).
    pub fn v7At(r: Random, ts_ms: u64) Uuid {
        var self: Uuid = .{ .bytes = undefined };
        // Fill all 16 bytes with random first
        r.bytes(&self.bytes);
        // Overwrite first 6 bytes with 48-bit timestamp, big-endian
        mem.writeInt(u48, self.bytes[0..6], @truncate(ts_ms), .big);
        // Version 7 → byte 6 high nibble = 0111
        self.bytes[6] = 0x70 | (self.bytes[6] & 0x0f);
        // Variant RFC4122 → byte 8 high two bits = 10
        self.bytes[8] = (self.bytes[8] & 0x3f) | 0x80;
        return self;
    }

    // ---------- Parse / format ----------

    pub const ParseError = error{
        InvalidLength,
        InvalidHex,
        InvalidVersion,
        InvalidVariant,
    };

    /// Parse a UUID string.
    /// Accepts both hyphenated canonical form (`8-4-4-4-12`, 36 chars) and
    /// non-hyphenated compact form (32 hex chars). Case-insensitive on input.
    /// Validates version (RFC 4122/9562: 1, 3, 4, 5, 6, 7, 8) and variant (10xx).
    pub fn parse(s: []const u8) ParseError!Uuid {
        const Hyphenated = 36;
        const NonHyphenated = 32;

        if (s.len != Hyphenated and s.len != NonHyphenated) {
            return ParseError.InvalidLength;
        }

        // If hyphenated, check hyphen positions: 8, 13, 18, 23
        if (s.len == Hyphenated) {
            if (s[8] != '-' or s[13] != '-' or s[18] != '-' or s[23] != '-') {
                return ParseError.InvalidLength;
            }
        }

        var result: Uuid = .{ .bytes = undefined };
        var byte_idx: usize = 0;
        var i: usize = 0;
        while (i < s.len) : (i += 1) {
            // Skip hyphens in canonical form
            if (s.len == Hyphenated and (i == 8 or i == 13 or i == 18 or i == 23)) {
                continue;
            }
            // Need at least 1 more char for the low nibble
            if (i + 1 >= s.len) return ParseError.InvalidLength;
            const hi = hexValue(s[i]) orelse return ParseError.InvalidHex;
            const lo = hexValue(s[i + 1]) orelse return ParseError.InvalidHex;
            result.bytes[byte_idx] = (@as(u8, hi) << 4) | @as(u8, lo);
            byte_idx += 1;
            i += 1;
        }

        if (byte_idx != 16) return ParseError.InvalidLength;

        // Validate version (RFC 4122/9562 valid set: 1, 3, 4, 5, 6, 7, 8)
        const ver = result.bytes[6] >> 4;
        const ver_valid = (ver == 1) or (ver == 3) or (ver == 4) or (ver == 5) or (ver == 6) or (ver == 7) or (ver == 8);
        if (!ver_valid) return ParseError.InvalidVersion;

        // Validate variant (RFC 4122/9562: top 2 bits = 10)
        if ((result.bytes[8] & 0xc0) != 0x80) return ParseError.InvalidVariant;

        return result;
    }

    /// Format as canonical 8-4-4-4-12 lowercase hex string into any Writer.
    /// Writer is `anytype` for compatibility with `*std.io.Writer` (legacy)
    /// and `*std.Io.Writer` (0.16+).
    pub fn format(self: Uuid, w: anytype) !void {
        try writeHexBytes(w, self.bytes[0..4]);
        try w.writeByte('-');
        try writeHexBytes(w, self.bytes[4..6]);
        try w.writeByte('-');
        try writeHexBytes(w, self.bytes[6..8]);
        try w.writeByte('-');
        try writeHexBytes(w, self.bytes[8..10]);
        try w.writeByte('-');
        try writeHexBytes(w, self.bytes[10..16]);
    }

    // ---------- Accessors ----------

    /// Detect version from byte 6 high nibble.
    /// Returns the known Version enum, or an unknown bit pattern as a raw u4.
    pub fn version(self: Uuid) Version {
        return @enumFromInt(self.bytes[6] >> 4);
    }

    /// True if variant bits match RFC4122 (10xx).
    pub fn isRfc4122(self: Uuid) bool {
        return (self.bytes[8] & 0xc0) == 0x80;
    }
};

// ---------- Helpers (file-private) ----------

/// Map a hex character to its numeric value. Returns null for non-hex.
fn hexValue(c: u8) ?u4 {
    return switch (c) {
        '0'...'9' => @intCast(c - '0'),
        'a'...'f' => @intCast(c - 'a' + 10),
        'A'...'F' => @intCast(c - 'A' + 10),
        else => null,
    };
}

/// Write `bytes` as lowercase hex into `w`.
fn writeHexBytes(w: anytype, bytes: []const u8) !void {
    const hex_chars = "0123456789abcdef";
    for (bytes) |b| {
        try w.writeByte(hex_chars[b >> 4]);
        try w.writeByte(hex_chars[b & 0x0f]);
    }
}

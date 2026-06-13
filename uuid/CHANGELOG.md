# Changelog — `uuid`

Format: [Keep a Changelog](https://keepachangelog.com)

## [0.1.0-dev] — unreleased

### Added
- `Uuid.v4(r: Random)` — random v4 UUID
- `Uuid.v7At(r: Random, ts_ms: u64)` — v7 with explicit timestamp
- `Uuid.parse(s: []const u8) ParseError!Uuid` — parse canonical (36) or compact (32) hex form, case-insensitive
- `Uuid.format(self, w: anytype) !void` — write canonical 8-4-4-4-12 lowercase form to any writer
- `Uuid.version() -> Version` — accessor
- `Uuid.isRfc4122() -> bool` — accessor
- `Version` enum (`v1`, `v4`, `v7`)
- `ParseError` set: `InvalidLength`, `InvalidHex`, `InvalidVersion`, `InvalidVariant`
- Test coverage (23 tests): v4/v7 bit setting, uniqueness (1000 ids), timestamp encoding, accessor correctness, parse canonical/uppercase/compact, format roundtrips, all error paths, zero-UUID behavior

### Removed
- `Uuid.v7(r: Random)` — Zig 0.16 has no `std.time.milliTimestamp`. Use `v7At` with your own timestamp from `Io.Clock.now` or `std.posix.clock_gettime`

### Notes
- API frozen at this version. No breaking changes until 1.0.0
- format() uses `anytype` writer for compatibility with both legacy `*std.io.Writer` and new `*std.Io.Writer`
- The all-zero UUID (nil) parses as `InvalidVariant` — historically called "nil UUID" but not RFC 4122 compliant
- Verified on Zig 0.16.0 / Windows x86_64. Cross-OS testing pending (CI to be set up)

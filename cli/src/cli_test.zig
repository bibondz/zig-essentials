//! RED tests for `cli` parser.
//!
//! All tests in this file are expected to FAIL until the impl lands.
//! Run: `cd cli && zig build test` (after fingerprint is set).

const std = @import("std");
const testing = std.testing;
const cli = @import("cli.zig");

// ---------- Test fixtures ----------

/// Standard test args used by most tests.
const TestArgs = struct {
    verbose: bool = false,
    output: []const u8 = "",
    file: []const u8 = "",
};

const test_schema: cli.Schema = .{
    .name = "test",
    .opts = &[_]cli.Opt{
        .{ .name = "verbose", .short = 'v', .kind = .flag, .help = "be loud" },
        .{ .name = "output", .short = 'o', .kind = .option, .help = "output file" },
    },
    .positionals = &[_]cli.Positional{
        .{ .name = "file", .help = "input file" },
    },
};

// Variant with optional positional + many, for testing those.
const ManyArgs = struct {
    name: []const u8 = "default",
    files: []const u8 = "",
};

const many_schema: cli.Schema = .{
    .name = "many",
    .positionals = &[_]cli.Positional{
        .{ .name = "name", .required = false, .help = "name (optional)" },
        .{ .name = "files", .many = true, .help = "zero or more files" },
    },
};

// ---------- Success cases ----------

test "empty argv uses all defaults" {
    const argv = [_][]const u8{"test"};
    const args = try cli.parse(TestArgs, test_schema, &argv);
    try testing.expectEqual(false, args.verbose);
    try testing.expectEqualStrings("", args.output);
    try testing.expectEqualStrings("", args.file);
}

test "--verbose sets flag to true" {
    const argv = [_][]const u8{ "test", "--verbose" };
    const args = try cli.parse(TestArgs, test_schema, &argv);
    try testing.expectEqual(true, args.verbose);
}

test "-v is short form of --verbose" {
    const argv = [_][]const u8{ "test", "-v" };
    const args = try cli.parse(TestArgs, test_schema, &argv);
    try testing.expectEqual(true, args.verbose);
}

test "--output=foo sets option via equals" {
    const argv = [_][]const u8{ "test", "--output=foo" };
    const args = try cli.parse(TestArgs, test_schema, &argv);
    try testing.expectEqualStrings("foo", args.output);
}

test "--output foo sets option via space" {
    const argv = [_][]const u8{ "test", "--output", "foo" };
    const args = try cli.parse(TestArgs, test_schema, &argv);
    try testing.expectEqualStrings("foo", args.output);
}

test "-o short option with space" {
    const argv = [_][]const u8{ "test", "-o", "foo" };
    const args = try cli.parse(TestArgs, test_schema, &argv);
    try testing.expectEqualStrings("foo", args.output);
}

test "positional file at end" {
    const argv = [_][]const u8{ "test", "input.txt" };
    const args = try cli.parse(TestArgs, test_schema, &argv);
    try testing.expectEqualStrings("input.txt", args.file);
}

test "all combined: flag + option + positional" {
    const argv = [_][]const u8{ "test", "-v", "-o", "out.txt", "input.txt" };
    const args = try cli.parse(TestArgs, test_schema, &argv);
    try testing.expectEqual(true, args.verbose);
    try testing.expectEqualStrings("out.txt", args.output);
    try testing.expectEqualStrings("input.txt", args.file);
}

test "all combined in different order" {
    const argv = [_][]const u8{ "test", "input.txt", "-v", "--output=out.txt" };
    const args = try cli.parse(TestArgs, test_schema, &argv);
    try testing.expectEqual(true, args.verbose);
    try testing.expectEqualStrings("out.txt", args.output);
    try testing.expectEqualStrings("input.txt", args.file);
}

test "optional positional not provided" {
    const argv = [_][]const u8{"many"};
    const args = try cli.parse(ManyArgs, many_schema, &argv);
    try testing.expectEqualStrings("default", args.name);
    try testing.expectEqualStrings("", args.files);
}

test "many positional collects multiple values" {
    const argv = [_][]const u8{ "many", "a.txt", "b.txt", "c.txt" };
    const args = try cli.parse(ManyArgs, many_schema, &argv);
    try testing.expectEqualStrings("a.txt", args.name);
    try testing.expectEqualStrings("a.txt,b.txt,c.txt", args.files);
}

// ---------- Error cases ----------

test "unknown long flag → UnknownFlag" {
    const argv = [_][]const u8{ "test", "--unknown" };
    try testing.expectError(cli.ParseError.UnknownFlag, cli.parse(TestArgs, test_schema, &argv));
}

test "unknown short flag → UnknownFlag" {
    const argv = [_][]const u8{ "test", "-x" };
    try testing.expectError(cli.ParseError.UnknownFlag, cli.parse(TestArgs, test_schema, &argv));
}

test "missing required positional → MissingPositional" {
    const argv = [_][]const u8{ "test", "-v" };
    try testing.expectError(cli.ParseError.MissingPositional, cli.parse(TestArgs, test_schema, &argv));
}

test "too many positionals → TooManyPositionals" {
    const argv = [_][]const u8{ "test", "a", "b" }; // schema has only 1 positional
    try testing.expectError(cli.ParseError.TooManyPositionals, cli.parse(TestArgs, test_schema, &argv));
}

test "option at end of argv with no value → MissingValue" {
    const argv = [_][]const u8{ "test", "--output" };
    try testing.expectError(cli.ParseError.MissingValue, cli.parse(TestArgs, test_schema, &argv));
}

// ---------- Help / version ----------

test "--help returns HelpRequested" {
    const argv = [_][]const u8{ "test", "--help" };
    try testing.expectError(cli.ParseError.HelpRequested, cli.parse(TestArgs, test_schema, &argv));
}

test "--version returns VersionRequested when schema has version" {
    const versioned: cli.Schema = .{
        .name = "test",
        .version = "1.0.0",
        .opts = &[_]cli.Opt{},
        .positionals = &[_]cli.Positional{},
    };
    const argv = [_][]const u8{ "test", "--version" };
    try testing.expectError(cli.ParseError.VersionRequested, cli.parse(TestArgs, versioned, &argv));
}

//! Tests for `cli` parser.
//! All tests should be GREEN now (impl is in src/cli.zig).

const std = @import("std");
const testing = std.testing;
const cli = @import("cli.zig");

// ---------- Test fixtures ----------

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

test "no flags = flag defaults" {
    // Required positional `file` must be provided; flag defaults still apply
    const argv = [_][]const u8{ "test", "input.txt" };
    const args = try cli.parse(TestArgs, test_schema, testing.allocator, &argv);
    try testing.expectEqual(false, args.verbose);
    try testing.expectEqualStrings("", args.output);
    try testing.expectEqualStrings("input.txt", args.file);
}

test "--verbose sets flag to true" {
    const argv = [_][]const u8{ "test", "--verbose", "input.txt" };
    const args = try cli.parse(TestArgs, test_schema, testing.allocator, &argv);
    try testing.expectEqual(true, args.verbose);
    try testing.expectEqualStrings("input.txt", args.file);
}

test "-v is short form of --verbose" {
    const argv = [_][]const u8{ "test", "-v", "input.txt" };
    const args = try cli.parse(TestArgs, test_schema, testing.allocator, &argv);
    try testing.expectEqual(true, args.verbose);
    try testing.expectEqualStrings("input.txt", args.file);
}

test "--output=foo sets option via equals" {
    const argv = [_][]const u8{ "test", "--output=foo", "input.txt" };
    const args = try cli.parse(TestArgs, test_schema, testing.allocator, &argv);
    try testing.expectEqualStrings("foo", args.output);
    try testing.expectEqualStrings("input.txt", args.file);
}

test "--output foo sets option via space" {
    const argv = [_][]const u8{ "test", "--output", "foo", "input.txt" };
    const args = try cli.parse(TestArgs, test_schema, testing.allocator, &argv);
    try testing.expectEqualStrings("foo", args.output);
    try testing.expectEqualStrings("input.txt", args.file);
}

test "-o short option with space" {
    const argv = [_][]const u8{ "test", "-o", "foo", "input.txt" };
    const args = try cli.parse(TestArgs, test_schema, testing.allocator, &argv);
    try testing.expectEqualStrings("foo", args.output);
    try testing.expectEqualStrings("input.txt", args.file);
}

test "positional file at end" {
    const argv = [_][]const u8{ "test", "input.txt" };
    const args = try cli.parse(TestArgs, test_schema, testing.allocator, &argv);
    try testing.expectEqualStrings("input.txt", args.file);
}

test "all combined: flag + option + positional" {
    const argv = [_][]const u8{ "test", "-v", "-o", "out.txt", "input.txt" };
    const args = try cli.parse(TestArgs, test_schema, testing.allocator, &argv);
    try testing.expectEqual(true, args.verbose);
    try testing.expectEqualStrings("out.txt", args.output);
    try testing.expectEqualStrings("input.txt", args.file);
}

test "all combined in different order" {
    const argv = [_][]const u8{ "test", "input.txt", "-v", "--output=out.txt" };
    const args = try cli.parse(TestArgs, test_schema, testing.allocator, &argv);
    try testing.expectEqual(true, args.verbose);
    try testing.expectEqualStrings("out.txt", args.output);
    try testing.expectEqualStrings("input.txt", args.file);
}

test "optional positional not provided" {
    const argv = [_][]const u8{"many"};
    const args = try cli.parse(ManyArgs, many_schema, testing.allocator, &argv);
    try testing.expectEqualStrings("default", args.name);
    try testing.expectEqualStrings("", args.files);
}

test "many positional collects multiple values (comma-joined)" {
    // many_schema has 2 positionals: `name` (not many, not required) and `files` (many)
    // "a.txt" fills `name`; "b.txt", "c.txt" go to `files` (many, comma-joined)
    // Use a real arena so allocations are freed when test ends
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const argv = [_][]const u8{ "many", "a.txt", "b.txt", "c.txt" };
    const args = try cli.parse(ManyArgs, many_schema, arena.allocator(), &argv);
    try testing.expectEqualStrings("a.txt", args.name);
    try testing.expectEqualStrings("b.txt,c.txt", args.files);
}

// ---------- Error cases ----------

test "unknown long flag → UnknownFlag" {
    const argv = [_][]const u8{ "test", "--unknown" };
    try testing.expectError(cli.ParseError.UnknownFlag, cli.parse(TestArgs, test_schema, testing.allocator, &argv));
}

test "unknown short flag → UnknownFlag" {
    const argv = [_][]const u8{ "test", "-x" };
    try testing.expectError(cli.ParseError.UnknownFlag, cli.parse(TestArgs, test_schema, testing.allocator, &argv));
}

test "missing required positional → MissingPositional" {
    const argv = [_][]const u8{ "test", "-v" };
    try testing.expectError(cli.ParseError.MissingPositional, cli.parse(TestArgs, test_schema, testing.allocator, &argv));
}

test "too many positionals → TooManyPositionals" {
    const argv = [_][]const u8{ "test", "a", "b" }; // schema has only 1 positional
    try testing.expectError(cli.ParseError.TooManyPositionals, cli.parse(TestArgs, test_schema, testing.allocator, &argv));
}

test "option at end of argv with no value → MissingValue" {
    const argv = [_][]const u8{ "test", "--output" };
    try testing.expectError(cli.ParseError.MissingValue, cli.parse(TestArgs, test_schema, testing.allocator, &argv));
}

// ---------- Help / version ----------

test "--help returns HelpRequested" {
    const argv = [_][]const u8{ "test", "--help" };
    try testing.expectError(cli.ParseError.HelpRequested, cli.parse(TestArgs, test_schema, testing.allocator, &argv));
}

test "--version returns VersionRequested when schema has version" {
    const versioned: cli.Schema = .{
        .name = "test",
        .version = "1.0.0",
        .opts = &[_]cli.Opt{},
        .positionals = &[_]cli.Positional{},
    };
    const argv = [_][]const u8{ "test", "--version" };
    try testing.expectError(cli.ParseError.VersionRequested, cli.parse(TestArgs, versioned, testing.allocator, &argv));
}

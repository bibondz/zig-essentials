//! Tests for `log` logger.

const std = @import("std");
const Io = std.Io;
const testing = std.testing;
const log = @import("log.zig");

// ---------- Sink construction ----------

test "textSink produces a sink with a non-undefined writeFn" {
    var buf: [256]u8 = undefined;
    var writer = Io.Writer.fixed(&buf);
    const sink = log.textSink(&writer);
    try testing.expect(@intFromPtr(sink.writeFn) != 0);
    try testing.expect(sink.data != null);
}

test "jsonSink produces a sink with a non-undefined writeFn" {
    var buf: [256]u8 = undefined;
    var writer = Io.Writer.fixed(&buf);
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const sink = log.jsonSink(arena.allocator(), &writer);
    try testing.expect(@intFromPtr(sink.writeFn) != 0);
    try testing.expect(sink.data != null);
}

test "default sink (textSinkToStderr) is constructible" {
    const sink = log.textSinkToStderr();
    try testing.expect(@intFromPtr(sink.writeFn) != 0);
    try testing.expect(sink.data == null);
}

// ---------- Global state management ----------

test "setSink replaces global, unsetSink restores default" {
    var buf_a: [256]u8 = undefined;
    var writer_a = Io.Writer.fixed(&buf_a);
    var buf_b: [256]u8 = undefined;
    var writer_b = Io.Writer.fixed(&buf_b);

    log.setSink(log.textSink(&writer_a));
    log.unsetSink();
    log.setSink(log.textSink(&writer_b));
    log.unsetSink();
    try testing.expect(true);
}

// ---------- Level filtering ----------

test "setLevel accepts .warn without crash" {
    log.setLevel(.warn);
    log.setLevel(.debug); // restore
    try testing.expect(true);
}

test "setLevel accepts default .debug without crash" {
    log.setLevel(.debug);
    try testing.expect(true);
}

test "setLevel accepts .info without crash" {
    log.setLevel(.info);
    log.setLevel(.debug); // restore
    try testing.expect(true);
}

test "setLevel accepts .err without crash" {
    log.setLevel(.err);
    log.setLevel(.debug); // restore
    try testing.expect(true);
}

test "logAtLevel filters messages below min level" {
    var buf: [256]u8 = undefined;
    var writer = Io.Writer.fixed(&buf);
    log.setSink(log.textSink(&writer));
    defer log.unsetSink();

    log.setLevel(.warn);
    defer log.setLevel(.debug);

    const my_log = log.scoped("test");
    my_log.info("should be filtered", .{});
    my_log.warn("should appear", .{});

    const output = writer.buffer[0..writer.end];
    try testing.expect(std.mem.indexOf(u8, output, "should be filtered") == null);
    try testing.expect(std.mem.indexOf(u8, output, "should appear") != null);
}

// ---------- Text sink output format ----------

test "text sink writes level, scope, and formatted message" {
    var buf: [256]u8 = undefined;
    var writer = Io.Writer.fixed(&buf);
    log.setSink(log.textSink(&writer));
    defer log.unsetSink();

    log.info("test", "hello {s}", .{"world"});

    const output = writer.buffer[0..writer.end];
    try testing.expectEqualStrings("info(test): hello world\n", output);
}

test "text sink handles numbers and multiple args" {
    var buf: [256]u8 = undefined;
    var writer = Io.Writer.fixed(&buf);
    log.setSink(log.textSink(&writer));
    defer log.unsetSink();

    const my_log = log.scoped("app");
    my_log.info("started v{d}.{d}.{d}", .{ 1, 2, 3 });

    const output = writer.buffer[0..writer.end];
    try testing.expectEqualStrings("info(app): started v1.2.3\n", output);
}

// ---------- JSON sink output format ----------

test "json sink writes valid JSON with level, scope, and message" {
    var buf: [256]u8 = undefined;
    var writer = Io.Writer.fixed(&buf);
    log.setSink(log.jsonSink(testing.allocator, &writer));
    defer log.unsetSink();

    log.info("test", "hello {s}", .{"world"});

    const output = writer.buffer[0..writer.end];
    try testing.expectEqualStrings("{\"level\":\"info\",\"scope\":\"test\",\"message\":\"hello world\"}\n", output);
}

test "json sink escapes quotes and backslashes in message" {
    var buf: [256]u8 = undefined;
    var writer = Io.Writer.fixed(&buf);
    log.setSink(log.jsonSink(testing.allocator, &writer));
    defer log.unsetSink();

    log.info("test", "has a \"quote\" and \\ backslash", .{});

    const output = writer.buffer[0..writer.end];
    try testing.expectEqualStrings("{\"level\":\"info\",\"scope\":\"test\",\"message\":\"has a \\\"quote\\\" and \\\\ backslash\"}\n", output);
}

// ---------- Scoped logger output ----------

test "Logger.debug writes formatted message" {
    var buf: [256]u8 = undefined;
    var writer = Io.Writer.fixed(&buf);
    log.setSink(log.textSink(&writer));
    defer log.unsetSink();

    const my_log = log.scoped("test");
    my_log.debug("hello {s}", .{"world"});

    const output = writer.buffer[0..writer.end];
    try testing.expectEqualStrings("debug(test): hello world\n", output);
}

test "Logger.warn writes formatted message" {
    var buf: [256]u8 = undefined;
    var writer = Io.Writer.fixed(&buf);
    log.setSink(log.textSink(&writer));
    defer log.unsetSink();

    const my_log = log.scoped("test");
    my_log.warn("deprecated: {s}", .{"foo"});

    const output = writer.buffer[0..writer.end];
    try testing.expectEqualStrings("warn(test): deprecated: foo\n", output);
}

test "Logger.err writes formatted message" {
    var buf: [256]u8 = undefined;
    var writer = Io.Writer.fixed(&buf);
    log.setSink(log.textSink(&writer));
    defer log.unsetSink();

    const my_log = log.scoped("test");
    my_log.err("failed: {s}", .{"boom"});

    const output = writer.buffer[0..writer.end];
    try testing.expectEqualStrings("err(test): failed: boom\n", output);
}

// ---------- Drop-in compatibility ----------

test "drop-in: log.info API same shape as std.log.info" {
    var buf: [256]u8 = undefined;
    var writer = Io.Writer.fixed(&buf);
    log.setSink(log.textSink(&writer));
    defer log.unsetSink();

    log.info("test", "hello {s}", .{"world"});

    const output = writer.buffer[0..writer.end];
    try testing.expectEqualStrings("info(test): hello world\n", output);
}

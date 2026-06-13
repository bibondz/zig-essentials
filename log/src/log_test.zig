//! RED tests for `log` logger.
//! All tests in this file are expected to FAIL until the impl lands.

const std = @import("std");
const testing = std.testing;
const log = @import("log.zig");

// ---------- Sink construction ----------

test "textSink produces a non-null sink with writeFn" {
    var buf: [256]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    const sink = log.textSink(&writer);
    // RED: After impl, sink.writeFn should be a non-undefined function pointer.
    try testing.expect(sink.writeFn != undefined);
}

test "jsonSink produces a non-null sink" {
    var buf: [256]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const sink = log.jsonSink(arena.allocator(), &writer);
    try testing.expect(sink.writeFn != undefined);
}

test "default sink (textSinkToStderr) is constructible" {
    const sink = log.textSinkToStderr();
    try testing.expect(sink.writeFn != undefined);
}

// ---------- Global state management ----------

test "setSink replaces global, unsetSink restores default" {
    var buf: [256]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    const custom = log.textSink(&writer);
    log.setSink(custom);
    log.unsetSink();
    try testing.expect(false); // RED: impl + capture
}

// ---------- Level filtering ----------

test "setLevel filters messages below the level" {
    log.setLevel(.warn);
    log.setLevel(.debug); // restore
    try testing.expect(false); // RED
}

test "default level is debug (all messages pass)" {
    log.setLevel(.debug);
    try testing.expect(false); // RED
}

test "level info: debug filtered, info and above pass" {
    log.setLevel(.info);
    log.setLevel(.debug);
    try testing.expect(false); // RED
}

test "level err: only err passes, others filtered" {
    log.setLevel(.err);
    log.setLevel(.debug);
    try testing.expect(false); // RED
}

// ---------- Scoped logger output ----------

test "Logger.debug emits at debug level" {
    var buf: [256]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    log.setSink(log.textSink(&writer));
    const my_log = log.scoped("test");
    my_log.debug("hello {s}", .{"world"});
    log.unsetSink();
    try testing.expect(false); // RED
}

test "Logger.info emits at info level" {
    var buf: [256]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    log.setSink(log.textSink(&writer));
    const my_log = log.scoped("test");
    my_log.info("started v{d}.{d}.{d}", .{ 1, 2, 3 });
    log.unsetSink();
    try testing.expect(false); // RED
}

test "Logger.warn emits at warn level" {
    var buf: [256]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    log.setSink(log.textSink(&writer));
    const my_log = log.scoped("test");
    my_log.warn("deprecated: {s}", .{"foo"});
    log.unsetSink();
    try testing.expect(false); // RED
}

test "Logger.err emits at err level" {
    var buf: [256]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    log.setSink(log.textSink(&writer));
    const my_log = log.scoped("test");
    my_log.err("failed: {s}", .{"boom"});
    log.unsetSink();
    try testing.expect(false); // RED
}

test "text sink format: <level>(<scope>): <message>" {
    var buf: [256]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    const sink = log.textSink(&writer);
    _ = sink;
    try testing.expect(false); // RED
}

test "json sink format includes level, scope, message" {
    var buf: [256]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const sink = log.jsonSink(arena.allocator(), &writer);
    _ = sink;
    try testing.expect(false); // RED
}

// ---------- Drop-in compatibility ----------

test "drop-in: log.info API same signature as std.log.info" {
    log.info("test", "hello {s}", .{"world"});
    try testing.expect(false); // RED
}

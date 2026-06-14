//! `log` — structured logger for Zig.
//!
//! Fills the gap in std (verified via `ZIG_STD_LIB_AUDIT.md`).
//!
//! ## Design (v0.1.0)
//!
//! - Drop-in compatible with `std.log`'s public API
//! - Pluggable sink: text (default), JSON, custom
//! - Per-call level: `debug` / `info` / `warn` / `err`
//! - Per-call scope (comptime, via `scoped(.scope_name)`)
//! - Compile-time format strings (like `std.log`)
//! - Runtime level filtering via `setLevel`
//!
//! ## Out of scope (deferred)
//!
//! - **Caller file:line** (v0.2.0)
//! - **Structured fields** (v0.2.0)
//! - **Async/shipping to remote** (v0.3.0+)
//! - **Log rotation** (filesystem concern)
//! - **Pretty colors in production** (terminal sinks only, planned separately)
//!
//! ## Stability
//!
//! API frozen at 0.1.0. New features = new functions, not signature changes.
//!
//! ## Implementation note (v0.1.0)
//!
//! `Sink.writeFn` takes a pre-formatted `message: []const u8` rather than a
//! `comptime fmt` + `fmt_args: anytype`. In Zig 0.16 a function pointer whose
//! target has a `comptime` parameter or an `anytype` parameter is a generic
//! function pointer, and the compiler rejects calling a generic function
//! through a runtime pointer (error: "generic function being called must be
//! comptime-known"). The global `current_sink` is a runtime `var`, so
//! `current_sink.writeFn(...)` cannot be monomorphized unless `writeFn` is a
//! plain non-generic function.
//!
//! To preserve the public log API (`comptime fmt` + args tuple), `logAtLevel`
//! formats the message at the call site via `std.fmt.comptimePrint` and
//! passes the resulting runtime `[]const u8` to the sink. This keeps the
//! user-facing API unchanged while making runtime sink dispatch legal.

const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

/// Log level. Lower priority messages filtered when min level is set higher.
pub const Level = enum { debug, info, warn, err };

/// A sink is the destination for log messages. Implement `writeFn` to handle
/// each message. The `data` field is opaque user data (e.g., a Writer pointer).
pub const Sink = struct {
    writeFn: *const fn (sink_data: ?*anyopaque, level: Level, scope: []const u8, message: []const u8) void,
    data: ?*anyopaque,
};

/// Scoped logger. Created via `scoped(.scope_name)`.
pub const Logger = struct {
    scope: []const u8,
    pub fn debug(self: Logger, comptime fmt: []const u8, args: anytype) void { logAtLevel(.debug, self.scope, fmt, args); }
    pub fn info(self: Logger, comptime fmt: []const u8, args: anytype) void { logAtLevel(.info, self.scope, fmt, args); }
    pub fn warn(self: Logger, comptime fmt: []const u8, args: anytype) void { logAtLevel(.warn, self.scope, fmt, args); }
    pub fn err(self: Logger, comptime fmt: []const u8, args: anytype) void { logAtLevel(.err, self.scope, fmt, args); }
};

fn textWriteFn(sink_data: ?*anyopaque, level: Level, scope: []const u8, message: []const u8) void {
    const writer: *Io.Writer = @ptrCast(@alignCast(sink_data orelse return));
    writer.print("{s}({s}): {s}\n", .{ @tagName(level), scope, message }) catch return;
}

fn jsonWriteFn(sink_data: ?*anyopaque, level: Level, scope: []const u8, message: []const u8) void {
    const writer: *Io.Writer = @ptrCast(@alignCast(sink_data orelse return));
    writer.writeAll("{\"level\":\"") catch return;
    writer.writeAll(@tagName(level)) catch return;
    writer.writeAll("\",\"scope\":\"") catch return;
    writer.writeAll(scope) catch return;
    writer.writeAll("\",\"message\":\"") catch return;
    for (message) |c| {
        switch (c) {
            '\\' => writer.writeAll("\\\\") catch return,
            '"' => writer.writeAll("\\\"") catch return,
            else => writer.writeByte(c) catch return,
        }
    }
    writer.writeAll("\"}\n") catch return;
}

fn stderrWriteFn(sink_data: ?*anyopaque, level: Level, scope: []const u8, message: []const u8) void {
    _ = sink_data;
    var buffer: [256]u8 = undefined;
    const locked = std.debug.lockStderr(&buffer);
    defer std.debug.unlockStderr();
    const writer = &locked.file_writer.interface;
    writer.print("{s}({s}): {s}\n", .{ @tagName(level), scope, message }) catch return;
    writer.flush() catch return;
}

/// Current global sink. Default = text sink writing to stderr.
var current_sink: Sink = .{ .writeFn = stderrWriteFn, .data = null };

/// Current minimum log level. Messages with `level < min_level` are dropped.
var min_level: Level = .debug;

/// Replace the global sink with a custom one. Pass the result of
/// `textSink(writer)` or `jsonSink(allocator, writer)`, or build your own.
pub fn setSink(sink: Sink) void { current_sink = sink; }

/// Reset to the default sink (text to stderr).
pub fn unsetSink() void { current_sink = .{ .writeFn = stderrWriteFn, .data = null }; }

/// Create a text sink that writes formatted messages to `writer`.
/// Format: `<level>(<scope>): <message>\n` (similar to `std.log` default).
pub fn textSink(writer: *Io.Writer) Sink {
    return .{ .writeFn = textWriteFn, .data = @ptrCast(writer) };
}

/// Create a JSON sink that writes one JSON object per line to `writer`.
/// Format: `{"level":"info","scope":"myapp","message":"hello"}\n`.
pub fn jsonSink(allocator: Allocator, writer: *Io.Writer) Sink {
    _ = allocator;
    return .{ .writeFn = jsonWriteFn, .data = @ptrCast(writer) };
}

/// Default text sink writing to stderr.
pub fn textSinkToStderr() Sink {
    return .{ .writeFn = stderrWriteFn, .data = null };
}

/// Set the minimum log level. Messages with lower priority are dropped.
pub fn setLevel(level: Level) void { min_level = level; }

/// Create a scoped logger. The scope is a comptime string used as the
/// label in log output.
pub fn scoped(comptime scope: []const u8) Logger {
    return .{ .scope = scope };
}

/// Log a message at a specific level with a scope name. Most users should
/// use `Logger.info(...)` etc. via `scoped(...)` instead.
pub fn logAtLevel(level: Level, scope: []const u8, comptime fmt: []const u8, args: anytype) void {
    if (@intFromEnum(level) < @intFromEnum(min_level)) return;
    const message = std.fmt.comptimePrint(fmt, args);
    current_sink.writeFn(current_sink.data, level, scope, message);
}

/// Top-level debug log. Drop-in for `std.log.debug`.
pub fn debug(comptime scope: []const u8, comptime fmt: []const u8, args: anytype) void { logAtLevel(.debug, scope, fmt, args); }

/// Top-level info log. Drop-in for `std.log.info`.
pub fn info(comptime scope: []const u8, comptime fmt: []const u8, args: anytype) void { logAtLevel(.info, scope, fmt, args); }

/// Top-level warn log. Drop-in for `std.log.warn`.
pub fn warn(comptime scope: []const u8, comptime fmt: []const u8, args: anytype) void { logAtLevel(.warn, scope, fmt, args); }

/// Top-level err log. Drop-in for `std.log.err`.
pub fn err(comptime scope: []const u8, comptime fmt: []const u8, args: anytype) void { logAtLevel(.err, scope, fmt, args); }

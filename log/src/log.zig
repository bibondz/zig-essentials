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

const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

// ---------- Public types ----------

/// Log level. Lower priority messages filtered when min level is set higher.
pub const Level = enum {
    debug,
    info,
    warn,
    err,
};

/// A sink is the destination for log messages. Implement `writeFn` to handle
/// each message. The `data` field is opaque user data (e.g., a Writer pointer).
///
/// `writeFn` is called once per log call. It's allowed to allocate. For
/// high-throughput logging, the implementation should buffer and flush in a
/// background thread (out of scope for v0.1.0).
pub const Sink = struct {
    writeFn: *const fn (
        sink_data: ?*anyopaque,
        level: Level,
        scope: []const u8,
        comptime fmt: []const u8,
        fmt_args: anytype,
    ) void,
    data: ?*anyopaque,
};

/// Scoped logger. Created via `scoped(.scope_name)`.
/// Each method logs at the corresponding level, tagged with the scope.
pub const Logger = struct {
    scope: []const u8,

    pub fn debug(self: Logger, comptime fmt: []const u8, args: anytype) void {
        logAtLevel(.debug, self.scope, fmt, args);
    }
    pub fn info(self: Logger, comptime fmt: []const u8, args: anytype) void {
        logAtLevel(.info, self.scope, fmt, args);
    }
    pub fn warn(self: Logger, comptime fmt: []const u8, args: anytype) void {
        logAtLevel(.warn, self.scope, fmt, args);
    }
    pub fn err(self: Logger, comptime fmt: []const u8, args: anytype) void {
        logAtLevel(.err, self.scope, fmt, args);
    }
};

// ---------- Global state ----------

/// Current global sink. Default = text sink writing to stderr.
var current_sink: Sink = textSinkToStderr();

/// Current minimum log level. Messages with `level < min_level` are dropped.
var min_level: Level = .debug;

// ---------- Public API: sink management ----------

/// Replace the global sink with a custom one. Pass the result of
/// `textSink(writer)` or `jsonSink(allocator, writer)`, or build your own.
pub fn setSink(sink: Sink) void {
    current_sink = sink;
}

/// Reset to the default sink (text to stderr).
pub fn unsetSink() void {
    current_sink = textSinkToStderr();
}

/// Create a text sink that writes formatted messages to `writer`.
/// Format: `<level>(<scope>): <message>\n` (similar to `std.log` default).
pub fn textSink(writer: *Io.Writer) Sink {
    _ = writer;
    // v0.1.0 stub
    return .{ .writeFn = undefined, .data = null };
}

/// Create a JSON sink that writes one JSON object per line to `writer`.
/// Format: `{"level":"info","scope":"myapp","message":"hello"}\n`.
pub fn jsonSink(allocator: Allocator, writer: *Io.Writer) Sink {
    _ = allocator;
    _ = writer;
    // v0.1.0 stub
    return .{ .writeFn = undefined, .data = null };
}

/// Default text sink writing to stderr.
pub fn textSinkToStderr() Sink {
    // v0.1.0 stub
    return .{ .writeFn = undefined, .data = null };
}

// ---------- Public API: level filter ----------

/// Set the minimum log level. Messages with lower priority are dropped.
pub fn setLevel(level: Level) void {
    min_level = level;
}

// ---------- Public API: scoped logger ----------

/// Create a scoped logger. The scope is a comptime string used as the
/// label in log output.
///
/// v0.1.0 uses string scope (not std.log's enum literal) to avoid
/// Zig 0.16's strict enum literal typing. v0.2.0 may add std.log-compatible
/// enum tag overload if there's demand.
///
/// Example:
/// ```
/// const my_log = log.scoped("myapp");
/// my_log.info("starting up");
/// ```
pub fn scoped(comptime scope: []const u8) Logger {
    _ = scope;
    // v0.1.0 stub
    return .{ .scope = "" };
}

// ---------- Public API: direct logging ----------

/// Log a message at a specific level with a scope name. Most users should
/// use `Logger.info(...)` etc. via `scoped(...)` instead.
pub fn logAtLevel(level: Level, scope: []const u8, comptime fmt: []const u8, args: anytype) void {
    _ = level;
    _ = scope;
    _ = fmt;
    _ = args;
    // v0.1.0 stub
}

/// Top-level debug log. Drop-in for `std.log.debug`.
pub fn debug(comptime scope: []const u8, comptime fmt: []const u8, args: anytype) void {
    logAtLevel(.debug, scope, fmt, args);
}

/// Top-level info log. Drop-in for `std.log.info`.
pub fn info(comptime scope: []const u8, comptime fmt: []const u8, args: anytype) void {
    logAtLevel(.info, scope, fmt, args);
}

/// Top-level warn log. Drop-in for `std.log.warn`.
pub fn warn(comptime scope: []const u8, comptime fmt: []const u8, args: anytype) void {
    logAtLevel(.warn, scope, fmt, args);
}

/// Top-level err log. Drop-in for `std.log.err`.
pub fn err(comptime scope: []const u8, comptime fmt: []const u8, args: anytype) void {
    logAtLevel(.err, scope, fmt, args);
}

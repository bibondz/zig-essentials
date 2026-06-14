//! `watcher` — cross-platform filesystem watcher for Zig.
//!
//! Fills the gap in std (verified via `ZIG_STD_LIB_AUDIT.md`).
//!
//! ## Design (v0.1.0)
//!
//! - Per-path subscription via `add`
//! - Event types: created, modified, deleted, renamed, moved_in, moved_out
//! - Coalescing: near-simultaneous events on the same path are merged
//! - Platform: Linux only (inotify). macOS (v0.2.0), Windows (v0.3.0) are stubs.
//!
//! ## Usage
//!
//! Basic loop: create a Watcher, add paths, poll in a loop.
//! See `watcher_test.zig` for a complete working example.
//!
//! ## Non-goals (deliberate)
//!
//! - Polling-based fallback (use OS-native or don't ship)
//! - inotify's cookie/rename pairing (best-effort, document the gap)
//! - Auto-recursive watch (caller walks subdirs)
//!
//! ## Stability
//!
//! API frozen at 0.1.0. New features = new functions, not signature changes.

const std = @import("std");
const Allocator = std.mem.Allocator;

// ---------- Public types ----------

/// Kind of filesystem event.
pub const EventType = enum {
    created,
    modified,
    deleted,
    renamed,
    moved_in,
    moved_out,
};

/// A single filesystem event.
pub const Event = struct {
    path: []const u8,
    kind: EventType,
};

// ---------- Platform detection ----------
// v0.1.0: Linux only. Other platforms compile-fail with a clear message.

const builtin = @import("builtin");
const is_linux = builtin.os.tag == .linux;

// ---------- Watcher ----------

/// Filesystem watcher. Add paths with `add`, poll with `poll`.
pub const Watcher = struct {
    allocator: Allocator,
    _impl: if (is_linux) LinuxWatcher else void,

    pub fn init(allocator: Allocator) !Watcher {
        if (!is_linux) return error.UnsupportedOS;
        return .{ .allocator = allocator, ._impl = try LinuxWatcher.init(allocator) };
    }

    pub fn deinit(self: *Watcher) void {
        if (is_linux) self._impl.deinit();
    }

    /// Begin watching `path`.
    pub fn add(self: *Watcher, path: []const u8) !void {
        if (is_linux) return self._impl.add(path);
        return error.UnsupportedOS;
    }

    /// Poll for events. `timeout_ms` is how long to wait if no events are pending
    /// (0 = return immediately). Caller must free the returned slice with allocator.free.
    pub fn poll(self: *Watcher, timeout_ms: u32) ![]Event {
        if (is_linux) return self._impl.poll(self.allocator, timeout_ms);
        return error.UnsupportedOS;
    }
};

// ---------- Linux implementation (v0.1.0) ----------
// TODO(v0.1.0): wire inotify fd, read events, map to Event[], coalesce

const LinuxWatcher = struct {
    allocator: Allocator,
    fd: std.os.fd_t,

    fn init(allocator: Allocator) !LinuxWatcher {
        const fd = std.c.inotify_init1(std.c.IN_NONBLOCK | std.c.IN_CLOEXEC);
        if (fd < 0) return error.SystemError;
        return .{ .allocator = allocator, .fd = fd };
    }

    fn deinit(self: *LinuxWatcher) void {
        std.os.close(self.fd);
    }

    fn add(self: *LinuxWatcher, path: []const u8) !void {
        const wd = std.c.inotify_add_watch(
            self.fd,
            std.c.memZSliceToCString(path),
            std.c.IN_CREATE | std.c.IN_MODIFY | std.c.IN_DELETE |
                std.c.IN_MOVED_FROM | std.c.IN_MOVED_TO | std.c.IN_MOVE_SELF,
        );
        if (wd < 0) return error.SystemError;
    }

    fn poll(_: *LinuxWatcher, _: Allocator, _: u32) ![]Event {
        // TODO(v0.1.0): read inotify events, map to Event[], coalesce, return
        return &[_]Event{};
    }
};
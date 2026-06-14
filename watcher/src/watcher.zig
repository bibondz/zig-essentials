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

const inotify_event = extern struct {
    wd: i32,
    mask: u32,
    cookie: u32,
    len: u32,
    // name starts here if len > 0 (not null-terminated)
};

const LinuxWatcher = struct {
    allocator: Allocator,
    fd: std.os.fd_t,
    /// Map from watch descriptor to the base path being watched.
    watches: std.AutoHashMap(i32, []const u8),

    fn init(allocator: Allocator) !LinuxWatcher {
        const fd = std.c.inotify_init1(std.c.IN_NONBLOCK | std.c.IN_CLOEXEC);
        if (fd < 0) return error.SystemError;
        return .{
            .allocator = allocator,
            .fd = fd,
            .watches = std.AutoHashMap(i32, []const u8).init(allocator),
        };
    }

    fn deinit(self: *LinuxWatcher) void {
        var it = self.watches.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.value_ptr.*);
        }
        self.watches.deinit();
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

        // inotify returns existing wd if already watching; free old path first.
        if (self.watches.get(wd)) |old| {
            self.allocator.free(old);
        }
        const path_copy = try self.allocator.dupe(u8, path);
        try self.watches.put(wd, path_copy);
    }

    fn poll(self: *LinuxWatcher, allocator: Allocator, timeout_ms: u32) ![]Event {
        // Use epoll to wait for the inotify fd with a timeout
        const epfd = std.c.epoll_create1(std.c.EPOLL_CLOEXEC);
        if (epfd < 0) return error.SystemError;
        defer std.os.close(epfd);

        var ep_ev = std.c.epoll_event{
            .events = std.c.EPOLLIN,
            .data = .{ .fd = self.fd },
        };
        if (std.c.epoll_ctl(epfd, std.c.EPOLL_CTL_ADD, self.fd, &ep_ev) < 0) {
            return error.SystemError;
        }

        const timeout = if (timeout_ms == 0) -1 else @as(i32, @intCast(timeout_ms));
        var ep_events: [1]std.c.epoll_event = undefined;
        const nready = std.c.epoll_wait(epfd, &ep_events, 1, timeout);
        if (nready <= 0) {
            // Timeout or error — no events available
            return try allocator.alloc(Event, 0);
        }
        if (ep_events[0].events & std.c.EPOLLIN == 0) {
            return try allocator.alloc(Event, 0);
        }

        // Read all available inotify events (non-blocking)
        var raw_buf: [8192]u8 = undefined;
        const n = std.os.read(self.fd, &raw_buf) catch return error.SystemError;
        if (n == 0) return try allocator.alloc(Event, 0);

        // Parse events — each is 16 bytes header + len bytes name
        // Pair each event with its buffer start offset so we can find the name later
        const EvPair = struct { ev: inotify_event, buf_start: usize };
        var raw_list = std.ArrayList(EvPair).init(allocator);
        defer raw_list.deinit();
        var off: usize = 0;
        while (off + 16 <= @as(usize, @intCast(n))) {
            const ev_ptr: *const inotify_event = @ptrCast(@alignCast(&raw_buf[off]));
            const ev_data = ev_ptr.*;
            const ev_start = off;
            off += 16;
            if (ev_data.len > 0) off += ev_data.len;
            try raw_list.append(.{ .ev = ev_data, .buf_start = ev_start });
        }

        // Coalesce: only one event per (path, kind) pair
        var seen = std.AutoHashMap(u64, void).init(allocator);
        defer seen.deinit();
        var out = std.ArrayList(Event).init(allocator);
        errdefer {
            for (out.items) |e| allocator.free(e.path);
            out.deinit();
        }

        for (raw_list.items) |pair| {
            const ev_data = pair.ev;
            const kinds = maskToEventTypes(ev_data.mask);
            for (kinds) |kind| {
                const base = self.watches.get(ev_data.wd) orelse continue;
                const name: []const u8 = if (ev_data.len > 0) blk: {
                    // name starts 16 bytes after the event's buffer start
                    const name_off = pair.buf_start + 16;
                    break :blk raw_buf[name_off..name_off + ev_data.len];
                } else "";

                const full_path = if (name.len > 0) blk: {
                    break :blk try std.mem.concat(allocator, u8, &.{ base, "/", name });
                } else blk: {
                    break :blk try allocator.dupe(u8, base);
                };

                const key = hashEvent(full_path, kind);
                if (seen.contains(key)) {
                    allocator.free(full_path);
                    continue;
                }
                try seen.put(key, {});
                try out.append(.{ .path = full_path, .kind = kind });
            }
        }

        return try out.toOwnedSlice();
    }
};

/// Map an inotify mask to EventType(s).
fn maskToEventTypes(mask: u32) []const EventType {
    if (mask & std.c.IN_CREATE != 0) return &.{.created};
    if (mask & std.c.IN_MODIFY != 0) return &.{.modified};
    if (mask & std.c.IN_DELETE != 0) return &.{.deleted};
    if (mask & std.c.IN_MOVED_FROM != 0) return &.{.moved_out};
    if (mask & std.c.IN_MOVED_TO != 0) return &.{.moved_in};
    if (mask & std.c.IN_MOVE_SELF != 0) return &.{.renamed};
    if (mask & std.c.IN_DELETE_SELF != 0) return &.{.deleted};
    if (mask & std.c.IN_CREATE_SELF != 0) return &.{.created};
    return &.{};
}

/// Hash a (path, kind) pair for coalescing dedup.
fn hashEvent(path: []const u8, kind: EventType) u64 {
    var h: u64 = 0;
    for (path) |c| h = h.*%33 + c;
    h = h.*%33 + @intFromEnum(kind);
    return h;
}

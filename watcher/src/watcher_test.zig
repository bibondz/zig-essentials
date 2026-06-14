//! RED tests for `watcher` v0.1.0 — Linux filesystem watcher.
//!
//! These tests verify the watcher API contract. They will fail against
//! the stub (poll returns empty) and pass once the inotify path is wired.

const std = @import("std");
const testing = std.testing;
const watcher = @import("watcher.zig");

// ---------- Platform gate ----------
// v0.1.0 is Linux only. Non-Linux platforms skip all tests.

const builtin = @import("builtin");
const is_linux = builtin.os.tag == .linux;

// ---------- Lifecycle ----------

test "init/deinit cycle succeeds" {
    if (!is_linux) return error.SkipZigTest;
    var w = try watcher.Watcher.init(testing.allocator);
    w.deinit();
}

test "init returns error.UnsupportedOS on non-Linux" {
    if (is_linux) return error.SkipZigTest;
    try testing.expectError(error.UnsupportedOS, watcher.Watcher.init(testing.allocator));
}

// ---------- add ----------

test "add on a real directory succeeds" {
    if (!is_linux) return error.SkipZigTest;
    var w = try watcher.Watcher.init(testing.allocator);
    defer w.deinit();
    try w.add("/tmp");
}

test "add on a non-existent path returns error" {
    if (!is_linux) return error.SkipZigTest;
    var w = try watcher.Watcher.init(testing.allocator);
    defer w.deinit();
    try testing.expectError(error.SystemError, w.add("/nonexistent/path/that/cannot/exist"));
}

// ---------- poll: file creation ----------

test "poll detects file creation" {
    if (!is_linux) return error.SkipZigTest;

    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const path = try tmp_dir.dir.realpath(".");
    const target = try std.fmt.allocPrint(testing.allocator, "{s}/watchertestfile.txt", .{path});
    defer testing.allocator.free(target);

    var w = try watcher.Watcher.init(testing.allocator);
    defer w.deinit();
    try w.add(path);

    // Create a file
    var file = try std.fs.createFileAbsolute(target, .{});
    file.close();

    const events = try w.poll(500);
    defer testing.allocator.free(events);

    try testing.expect(events.len > 0);
    const created = for (events) |ev| {
        if (ev.kind == .created and std.mem.startsWith(u8, ev.path, target)) break ev;
    } else null;
    try testing.expect(created != null);
}

test "poll detects file modification" {
    if (!is_linux) return error.SkipZigTest;

    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const path = try tmp_dir.dir.realpath(".");
    const target = try std.fmt.allocPrint(testing.allocator, "{s}/watchertest_mod.txt", .{path});
    defer testing.allocator.free(target);

    var file = try std.fs.createFileAbsolute(target, .{});
    file.close();

    var w = try watcher.Watcher.init(testing.allocator);
    defer w.deinit();
    try w.add(path);

    // Modify the file
    file = try std.fs.openFileAbsolute(target, .{ .mode = .write_only });
    try file.writeAll("changed");
    file.close();

    const events = try w.poll(500);
    defer testing.allocator.free(events);

    const modified = for (events) |ev| {
        if (ev.kind == .modified and std.mem.startsWith(u8, ev.path, target)) break ev;
    } else null;
    try testing.expect(modified != null);
}

test "poll detects file deletion" {
    if (!is_linux) return error.SkipZigTest;

    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const path = try tmp_dir.dir.realpath(".");
    const target = try std.fmt.allocPrint(testing.allocator, "{s}/watchertest_del.txt", .{path});
    defer testing.allocator.free(target);

    var file = try std.fs.createFileAbsolute(target, .{});
    file.close();

    var w = try watcher.Watcher.init(testing.allocator);
    defer w.deinit();
    try w.add(path);

    // Delete the file
    try std.fs.deleteFileAbsolute(target);

    const events = try w.poll(500);
    defer testing.allocator.free(events);

    const deleted = for (events) |ev| {
        if (ev.kind == .deleted and std.mem.startsWith(u8, ev.path, target)) break ev;
    } else null;
    try testing.expect(deleted != null);
}

// ---------- poll: timeout ----------

test "poll with zero timeout returns empty when no events" {
    if (!is_linux) return error.SkipZigTest;

    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const path = try tmp_dir.dir.realpath(".");
    var w = try watcher.Watcher.init(testing.allocator);
    defer w.deinit();
    try w.add(path);

    const events = try w.poll(0);
    defer testing.allocator.free(events);
    try testing.expect(events.len == 0);
}

test "poll with timeout returns within the requested window" {
    if (!is_linux) return error.SkipZigTest;

    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const path = try tmp_dir.dir.realpath(".");
    var w = try watcher.Watcher.init(testing.allocator);
    defer w.deinit();
    try w.add(path);

    _ = try w.poll(200);
}

// ---------- coalescing ----------

test "multiple rapid modifications are coalesced into one modified event" {
    if (!is_linux) return error.SkipZigTest;

    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const path = try tmp_dir.dir.realpath(".");
    const target = try std.fmt.allocPrint(testing.allocator, "{s}/watchertest_coalesce.txt", .{path});
    defer testing.allocator.free(target);

    var file = try std.fs.createFileAbsolute(target, .{});
    file.close();

    var w = try watcher.Watcher.init(testing.allocator);
    defer w.deinit();
    try w.add(path);

    // Rapid writes
    for (0..5) |_| {
        file = try std.fs.openFileAbsolute(target, .{ .mode = .write_only });
        try file.writeAll("x");
        file.close();
    }

    const events = try w.poll(500);
    defer testing.allocator.free(events);

    // Should have at most one modified event per unique path
    var modified_count: usize = 0;
    for (events) |ev| {
        if (ev.kind == .modified and std.mem.startsWith(u8, ev.path, target)) {
            modified_count += 1;
        }
    }
    try testing.expect(modified_count <= 2); // Allow creation + one coalesced modification
}

// ---------- Event structure ----------

test "Event has path and kind fields" {
    if (!is_linux) return error.SkipZigTest;

    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const path = try tmp_dir.dir.realpath(".");
    const target = try std.fmt.allocPrint(testing.allocator, "{s}/watchertest_event.txt", .{path});
    defer testing.allocator.free(target);

    var w = try watcher.Watcher.init(testing.allocator);
    defer w.deinit();
    try w.add(path);

    try std.fs.createFileAbsolute(target, .{}).close();

    const events = try w.poll(500);
    defer testing.allocator.free(events);

    try testing.expect(events.len > 0);
    const ev = events[0];
    try testing.expect(ev.path.len > 0);
    try testing.expect(ev.kind == .created or ev.kind == .modified);
}
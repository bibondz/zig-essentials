//! `cli` — struct-based CLI argument parser for Zig.
//!
//! Fills the gap in std (verified via `ZIG_STD_LIB_AUDIT.md`).
//!
//! ## Design (v0.1.0)
//!
//! - Declarative schema (comptime literal), parses to a user-defined struct
//! - Long flags (`--name`), short flags (`-n`), combined shorts (`-vfd` for bools)
//! - Options with values: `--name=val`, `--name val`, `-n val`, `-nval`
//! - Positional args (required, optional, or `many` for comma-joined list)
//! - Auto `--help` (always) and `--version` (if `schema.version` set)
//! - Compile-time schema↔struct check via `@hasField`
//!
//! ## Memory
//!
//! `parse()` takes an arena allocator for the `many` positional case
//! (joins values with `,`). Use any arena. For tests, `std.testing.allocator` works.
//!
//! ## Out of scope (v0.1.0)
//!
//! - Subcommands (planned v0.2.0)
//! - `--no-flag` negation
//! - Custom validators
//! - Type coercion (bool/int/float from string) — v0.1.0 only emits `[]const u8`
//!
//! ## Stability
//!
//! API frozen at 0.1.0. New features = new functions, not signature changes.

const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;

// ---------- Public types ----------

pub const Kind = enum {
    flag,
    option,
    option_list,
};

pub const Opt = struct {
    name: []const u8,
    short: ?u8 = null,
    kind: Kind,
    help: []const u8 = "",
    default: ?[]const u8 = null,
};

pub const Positional = struct {
    name: []const u8,
    required: bool = true,
    many: bool = false,
    help: []const u8 = "",
};

pub const Schema = struct {
    name: []const u8,
    version: ?[]const u8 = null,
    about: []const u8 = "",
    long_help: []const u8 = "",
    opts: []const Opt = &.{},
    positionals: []const Positional = &.{},
};

// ---------- Error set ----------

pub const ParseError = error{
    UnknownFlag,
    MissingValue,
    MissingPositional,
    TooManyPositionals,
    InvalidValue,
    HelpRequested,
    VersionRequested,
    OutOfMemory,
};

// ---------- Public API ----------

/// Parse `argv` (with program name as argv[0]) into a struct of type `T`.
///
/// `T` must have a field for every opt + positional in `schema` (compile-time
/// check via `@hasField`). Default values come from `T`'s field defaults.
///
/// `arena` is used for any allocations (currently: comma-join for `many`
/// positionals). The returned `T` may contain slices backed by `arena`.
pub fn parse(
    comptime T: type,
    comptime schema: Schema,
    arena: Allocator,
    argv: []const []const u8,
) ParseError!T {
    // Compile-time validation: every opt/positional in schema must be a field on T
    comptime {
        for (schema.opts) |opt| {
            if (!@hasField(T, opt.name)) {
                @compileError("schema has opt '" ++ opt.name ++ "' but T (" ++
                    @typeName(T) ++ ") has no such field");
            }
        }
        for (schema.positionals) |pos| {
            if (!@hasField(T, pos.name)) {
                @compileError("schema has positional '" ++ pos.name ++ "' but T (" ++
                    @typeName(T) ++ ") has no such field");
            }
        }
    }

    var result: T = .{};
    var positional_idx: usize = 0;
    var i: usize = 1; // skip program name

    while (i < argv.len) : (i += 1) {
        const arg = argv[i];

        // --help / -h
        if (mem.eql(u8, arg, "--help") or mem.eql(u8, arg, "-h")) {
            return ParseError.HelpRequested;
        }
        // --version
        if (mem.eql(u8, arg, "--version")) {
            if (schema.version == null) return ParseError.UnknownFlag;
            return ParseError.VersionRequested;
        }

        if (mem.startsWith(u8, arg, "--")) {
            // Long form: --name or --name=value
            const rest = arg[2..];
            const eq_idx = mem.indexOfScalar(u8, rest, '=');
            const name = if (eq_idx) |idx| rest[0..idx] else rest;
            const value_str: ?[]const u8 = if (eq_idx) |idx| rest[idx + 1 ..] else null;

            var matched = false;
            inline for (schema.opts) |o| {
                if (matched) {} else if (mem.eql(u8, o.name, name)) {
                    switch (o.kind) {
                        .flag => {
                            if (value_str) |v| {
                                if (mem.eql(u8, v, "true") or mem.eql(u8, v, "1")) {
                                    @field(result, o.name) = true;
                                } else if (mem.eql(u8, v, "false") or mem.eql(u8, v, "0")) {
                                    @field(result, o.name) = false;
                                } else {
                                    return ParseError.InvalidValue;
                                }
                            } else {
                                @field(result, o.name) = true;
                            }
                        },
                        .option, .option_list => {
                            const val = value_str orelse blk: {
                                i += 1;
                                if (i >= argv.len) return ParseError.MissingValue;
                                break :blk argv[i];
                            };
                            @field(result, o.name) = val;
                        },
                    }
                    matched = true;
                }
            }
            if (!matched) return ParseError.UnknownFlag;
        } else if (arg.len >= 2 and arg[0] == '-') {
            // Short form: -v, -o value, -ovalue, -vfd
            const rest = arg[1..];

            if (rest.len == 1) {
                // Single short: -v
                const ch = rest[0];
                var matched = false;
                inline for (schema.opts) |o| {
                    if (matched) {} else if (o.short) |s| {
                        if (s == ch) {
                            switch (o.kind) {
                                .flag => {
                                    @field(result, o.name) = true;
                                },
                                .option, .option_list => {
                                    i += 1;
                                    if (i >= argv.len) return ParseError.MissingValue;
                                    @field(result, o.name) = argv[i];
                                },
                            }
                            matched = true;
                        }
                    }
                }
                if (!matched) return ParseError.UnknownFlag;
            } else {
                // Multi-char short: -ovalue or -vfd
                // Do dispatch inside the inline for so o.name stays comptime
                const first_ch = rest[0];
                var dispatched = false;
                inline for (schema.opts) |o| {
                    if (o.short) |s| {
                        if (s == first_ch) {
                            if (o.kind == .flag) {
                                // Combined shorts: -vfd (all must be flags)
                                for (rest) |c| {
                                    inline for (schema.opts) |o2| {
                                        if (o2.short) |s2| {
                                            if (s2 == c) {
                                                if (o2.kind != .flag) return ParseError.InvalidValue;
                                                @field(result, o2.name) = true;
                                            }
                                        }
                                    }
                                }
                            } else {
                                // Inline value: -ovalue
                                @field(result, o.name) = rest[1..];
                            }
                            dispatched = true;
                        }
                    }
                }
                if (!dispatched) return ParseError.UnknownFlag;
            }
        } else {
            // Positional
            if (positional_idx >= schema.positionals.len) {
                return ParseError.TooManyPositionals;
            }
            // Find the current positional (comptime) via inline for
            // Use a handled flag to prevent the next iteration from also matching
            // (since incrementing positional_idx inside the handler would re-match)
            var handled = false;
            inline for (schema.positionals, 0..) |pos, pos_i| {
                if (handled) {} else if (pos_i == positional_idx) {
                    if (pos.many) {
                        // Comma-accumulate (uses arena)
                        const existing = @field(result, pos.name);
                        const new_val = if (existing.len == 0)
                            arg
                        else
                            try std.fmt.allocPrint(arena, "{s},{s}", .{ existing, arg });
                        @field(result, pos.name) = new_val;
                    } else {
                        @field(result, pos.name) = arg;
                        positional_idx += 1;
                    }
                    handled = true;
                }
            }
        }
    }

    // Post-loop: check required positionals
    inline for (schema.positionals) |pos| {
        if (pos.required and !pos.many) {
            const val = @field(result, pos.name);
            if (val.len == 0) return ParseError.MissingPositional;
        }
    }

    return result;
}

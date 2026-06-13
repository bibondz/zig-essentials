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

/// Discriminator for what an `Opt` accepts on the command line.
pub const Kind = enum {
    /// Boolean flag. `--verbose` → true. `--verbose=false` → false.
    /// Combinable with other flags in short form: `-vfd` sets all three to true.
    flag,
    /// Single string value. `--output=foo`, `--output foo`, `-o foo`, or `-ofoo`.
    option,
    /// String value that replaces any prior value. (Accumulation across
    /// multiple uses is not yet supported in v0.1.0 — last value wins.)
    /// Planned: comma-join accumulation in v0.2.0.
    option_list,
};

/// Declaration of one long/short flag. Compile-time literal in `Schema`.
///
/// The `name` field must match a field on the user's `T` struct (verified at
/// compile time via `@hasField`).
pub const Opt = struct {
    /// Long name without `--`, e.g. `"verbose"`. Must match a field on `T`.
    name: []const u8,
    /// Optional short letter, e.g. `'v'`. Conflicts with other opts' shorts
    /// in the same schema are not validated — duplicate shorts will cause
    /// only the first match to be applied.
    short: ?u8 = null,
    /// What kind of value this opt accepts.
    kind: Kind,
    /// Help text shown in `--help` output. v0.1.0 doesn't auto-generate help
    /// (caller prints schema manually on `HelpRequested`).
    help: []const u8 = "",
    /// Default value as string, used for `kind = .option` when the flag
    /// isn't provided on the command line. v0.1.0: documented but not yet
    /// applied — use `T`'s field default instead.
    default: ?[]const u8 = null,
};

/// Declaration of one positional argument.
///
/// In v0.1.0, the `name` field must match a field on the user's `T` struct
/// (verified at compile time). The field type is `[]const u8` — for `many`,
/// multiple values are joined with `,` into a single string.
pub const Positional = struct {
    /// Name used in help text and as the field name on `T`.
    name: []const u8,
    /// Whether this positional is required. Default: `true`.
    /// For `many = true`, `required` is ignored (0+ values are always accepted).
    required: bool = true,
    /// Accept multiple values, comma-joined into a single string. Default: `false`.
    /// Memory for the joined string comes from the `arena` passed to `parse()`.
    many: bool = false,
    /// Help text shown in `--help` output.
    help: []const u8 = "",
};

/// Top-level schema (comptime literal). Describes the entire CLI surface.
///
/// Build it as a struct literal and pass to `parse()`:
/// ```
/// const schema: Schema = .{
///     .name = "mytool",
///     .version = "1.0.0",
///     .opts = &.{ ... },
///     .positionals = &.{ ... },
/// };
/// ```
pub const Schema = struct {
    /// Program name (used in help text and error messages).
    name: []const u8,
    /// Version string. If non-null, `--version` is recognized and returns
    /// `VersionRequested` so the caller can print it and exit.
    version: ?[]const u8 = null,
    /// One-line description. v0.1.0: not auto-rendered; caller uses it in their help.
    about: []const u8 = "",
    /// Extended description. v0.1.0: not auto-rendered; caller uses it in their help.
    long_help: []const u8 = "",
    /// All long/short flag declarations.
    opts: []const Opt = &.{},
    /// All positional declarations.
    positionals: []const Positional = &.{},
};

// ---------- Error set ----------

/// Errors that `parse()` may return. Note: `HelpRequested` and `VersionRequested`
/// are not really errors — they're signals for the caller to print and exit 0.
pub const ParseError = error{
    /// A flag was passed that doesn't match any declared opt.
    UnknownFlag,
    /// An option (`--name`) was at the end of argv with no value following.
    MissingValue,
    /// A required positional was not provided.
    MissingPositional,
    /// More positionals were provided than declared.
    TooManyPositionals,
    /// A flag value couldn't be coerced (currently only used for `--flag=xyz`
    /// where xyz is not true/false/0/1).
    InvalidValue,
    /// `--help` or `-h` was passed. Caller should print help and exit 0.
    HelpRequested,
    /// `--version` was passed (only if `schema.version` is set). Caller should
    /// print the version and exit 0.
    VersionRequested,
    /// Arena allocation failed (e.g., out of memory while joining `many` values).
    OutOfMemory,
};

// ---------- Public API ----------

/// Parse `argv` (with program name as `argv[0]`) into a struct of type `T`.
///
/// **Type contract:** `T` must have a field for every opt + positional in
/// `schema` (compile-time check via `@hasField`). A missing field is a
/// `@compileError`, not a runtime error. Default values come from `T`'s
/// field defaults — use them instead of `Opt.default` in v0.1.0.
///
/// **Memory:** `arena` is used for any allocations (currently: comma-join
/// for `many` positionals). Slices in the returned `T` may point into `arena`.
/// Pass any `Allocator`; for tests use `std.testing.allocator` wrapped in
/// an `ArenaAllocator` so the joined strings get freed.
///
/// **Behavior on special args:**
/// - `--help` / `-h` → returns `HelpRequested`. Caller prints help + exits 0.
/// - `--version` → returns `VersionRequested` if `schema.version != null`.
///   Otherwise returns `UnknownFlag`.
///
/// **Long forms:** `--name`, `--name=value`
/// **Short forms:** `-n`, `-n value`, `-nvalue`, `-vfd` (combined bools)
///
/// **Positionals:** matched in order. Excess → `TooManyPositionals`.
/// Missing required → `MissingPositional`.
///
/// Example:
/// ```
/// const Args = struct {
///     verbose: bool = false,
///     output: []const u8 = "",
///     file: []const u8 = "",
/// };
/// var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
/// defer arena.deinit();
/// const args = try cli.parse(Args, .{
///     .name = "mytool",
///     .opts = &.{
///         .{ .name = "verbose", .short = 'v', .kind = .flag },
///         .{ .name = "output", .short = 'o', .kind = .option },
///     },
///     .positionals = &.{ .{ .name = "file" } },
/// }, arena.allocator(), std.os.argv);
/// ```
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

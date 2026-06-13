//! `cli` — struct-based CLI argument parser for Zig.
//!
//! Fills the gap in std (verified via `ZIG_STD_LIB_AUDIT.md`).
//!
//! ## Design (v0.1.0)
//!
//! - Declarative schema (comptime literal), parses to a user-defined struct
//! - Long flags (`--name`), short flags (`-n`), combined shorts (`-vfd`)
//! - Options with values: `--name=val`, `--name val`, `-n val`
//! - Positional args (required, optional, or `many`)
//! - Auto `--help` (always) and `--version` (if `schema.version` set)
//! - Compile-time schema-to-struct check via `@hasField`
//!
//! ## Out of scope (v0.1.0)
//!
//! - Subcommands (planned v0.2.0)
//! - `--no-flag` negation
//! - POSIX/GNU conflict resolution
//! - Custom validators
//! - Env var / config file fallback
//! - Shell completion
//!
//! ## Stability
//!
//! API frozen at 0.1.0. New features = new functions, not signature changes.

const std = @import("std");

// ---------- Public types ----------

/// Discriminator for what an `Opt` accepts on the command line.
pub const Kind = enum {
    /// Boolean flag. `--verbose` → true. `--verbose=false` → false.
    flag,
    /// Single string value. `--output=foo` or `--output foo`.
    option,
    /// Repeated string values. `--include a --include b` → ["a", "b"].
    option_list,
};

/// Declaration of one long/short flag.
pub const Opt = struct {
    /// Long name without `--`, e.g. `"verbose"`. Must match a field on T.
    name: []const u8,
    /// Optional short letter, e.g. `'v'`. Conflicts with other opts in the same schema.
    short: ?u8 = null,
    /// Whether this is a flag, single option, or repeatable option.
    kind: Kind,
    /// Help text shown in `--help` output.
    help: []const u8 = "",
    /// Default value as string. Only used for `kind = .option`.
    default: ?[]const u8 = null,
};

/// Declaration of one positional argument.
pub const Positional = struct {
    /// Name used in help text. Must match a field on T.
    name: []const u8,
    /// Whether this positional is required. Default: true.
    required: bool = true,
    /// Accept multiple values, packed into a comma-joined string?
    /// For v0.1.0: `many` is bool, multiple values are joined with `,`.
    /// For v0.2.0: may become a separate `[]const u8` type.
    many: bool = false,
    /// Help text shown in `--help` output.
    help: []const u8 = "",
};

/// Top-level schema (comptime literal).
pub const Schema = struct {
    /// Program name (used in help text).
    name: []const u8,
    /// Version string. If non-null, `--version` is recognized.
    version: ?[]const u8 = null,
    /// One-line description (first line of `--help`).
    about: []const u8 = "",
    /// Extended description (subsequent lines of `--help`).
    long_help: []const u8 = "",
    /// All long/short flag declarations.
    opts: []const Opt = &.{},
    /// All positional declarations.
    positionals: []const Positional = &.{},
};

// ---------- Error set ----------

pub const ParseError = error{
    /// A flag was passed that doesn't match any declared opt.
    UnknownFlag,
    /// An option (`--name`) was at the end of argv with no value following.
    MissingValue,
    /// A required positional was not provided.
    MissingPositional,
    /// More positionals were provided than declared.
    TooManyPositionals,
    /// A value couldn't be coerced to the target type.
    InvalidValue,
    /// `--help` was passed. Caller should print help and exit 0.
    HelpRequested,
    /// `--version` was passed. Caller should print version and exit 0.
    VersionRequested,
    /// Internal: stub returns this until v0.1.0 impl is done.
    Todo,
};

// ---------- Public API ----------

/// Parse `argv` (with program name as argv[0]) into a struct of type `T`.
///
/// `T` must have a field for every opt + positional in `schema` (compile-time
/// check via `@hasField`). Default values come from the struct's field defaults
/// or the `Opt.default` string (for `kind = .option`).
pub fn parse(comptime T: type, comptime schema: Schema, argv: []const []const u8) ParseError!T {
    _ = schema;
    _ = argv;
    // v0.1.0-dev: stub. Real impl in next session.
    return ParseError.Todo;
}

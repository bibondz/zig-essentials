# `cli` — struct-based CLI argument parser

> **Status:** v0.1.0 (first stable release) — API frozen. 18/18 tests pass on Zig 0.16.0.

Fills the gap in std: `process/Args.zig` has `iterate()` + `IteratorGeneral` (string splitter), but **no flag/subcommand/positional parser**. Verified via `ZIG_STD_LIB_AUDIT.md`.

## What you get (when impl lands)

```zig
const std = @import("std");
const cli = @import("cli");

const Args = struct {
    verbose: bool = false,
    output: []const u8 = "",
    file: []const u8 = "",
};

const args: Args = try cli.parse(Args, .{
    .name = "mytool",
    .version = "1.0.0",
    .about = "does the thing",
    .opts = &.{
        .{ .name = "verbose", .short = 'v', .kind = .flag, .help = "be loud" },
        .{ .name = "output", .short = 'o', .kind = .option, .help = "output file" },
    },
    .positionals = &.{
        .{ .name = "file", .help = "input file" },
    },
}, std.os.argv);
```

Then:

```bash
$ mytool --help
mytool v1.0.0 — does the thing

Usage: mytool [OPTIONS] <file>

Arguments:
  <file>  input file

Options:
  -v, --verbose         be loud
  -o, --output <OUT>    output file
      --help            Print help
      --version         Print version

$ mytool -v -o out.txt input.txt
# args.verbose = true, args.output = "out.txt", args.file = "input.txt"
```

## Design (v0.1.0)

| Feature | Status |
|---|---|
| Long flags (`--name`) | ✅ |
| Short flags (`-n`) | ✅ |
| Combined shorts (`-vfd` for bools only) | ✅ |
| Options with value: `--name=val`, `--name val`, `-n val` | ✅ |
| Positional args (required / optional / `many`) | ✅ |
| Auto `--help` | ✅ |
| Auto `--version` (when `schema.version` set) | ✅ |
| Compile-time schema ↔ struct check (via `@hasField`) | ✅ |
| Subcommands | ⏳ v0.2.0 |
| `--no-flag` negation | ⏳ v0.2.0 |
| Custom validators | ❌ |
| Env var / config file fallback | ❌ (use `toml` lib) |

## Out of scope (deliberate)

- ❌ POSIX/GNU conflict resolution (pick one convention, document it)
- ❌ Bash-style shell expansion
- ❌ Auto-completion scripts
- ❌ Plugin architecture
- ❌ Locale-aware help text

## API surface (will be frozen at 0.1.0)

| Type / function | Stable? |
|---|---|
| `cli.Kind` (`.flag`, `.option`, `.option_list`) | ✅ |
| `cli.Opt` (name, short, kind, help, default) | ✅ |
| `cli.Positional` (name, required, many, help) | ✅ |
| `cli.Schema` (name, version, about, long_help, opts, positionals) | ✅ |
| `cli.ParseError` (8 variants) | ✅ |
| `cli.parse(T, schema, argv)` | ✅ |

## Build / test

```bash
cd cli
zig build test
```

Currently: 0/18 pass (TDD RED). Next session: impl + GREEN.

## Test coverage (what RED tests assert)

**Success cases (12):**
- Empty argv uses defaults
- `--verbose` / `-v` set flag
- `--output=foo`, `--output foo`, `-o foo` set option
- Positional file at end
- All combined in different orders
- Optional positional not provided
- `many` positional collects multiple values

**Error cases (5):**
- Unknown long flag → `UnknownFlag`
- Unknown short flag → `UnknownFlag`
- Missing required positional → `MissingPositional`
- Too many positionals → `TooManyPositionals`
- Option at end with no value → `MissingValue`

**Help / version (2):**
- `--help` → `HelpRequested` (caller prints help, exits 0)
- `--version` → `VersionRequested` (caller prints version, exits 0)

## Non-goals reminder

Per PROJECT_PLAN.md §1 principles (explicit/robust/practical/stable), we don't add features "for the future." Subcommands are explicitly deferred to v0.2.0. If you need them now, use a different lib or contribute to v0.2.0 planning.

## License

MIT.

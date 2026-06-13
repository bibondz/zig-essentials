# Contributing

Thank you for considering a contribution. This project is small, deliberate, and opinionated. Please read this before opening a PR.

## TL;DR rules

1. **TDD mandatory** — failing test first, then impl, then refactor
2. **No LLM-generated code** — human-authored only
3. **Public API change** = new function OR major version bump (never edit in place)
4. **Changelog entry required** for every change that ships
5. **One concern per commit** — no "drive-by" refactors bundled with features
6. **Tests must pass** on Zig `LTS-0.16` (currently `0.16.0`) before review

## Workflow

```
1. Open issue (or comment on existing one) describing the change
2. Fork → branch → TDD: write failing test → make it pass → refactor
3. Add CHANGELOG entry (see format below)
4. Open PR with:
   - "What" and "Why" in the description
   - Test plan (commands + expected output)
   - Any breaking change explicitly called out
5. Maintainer review → merge
```

## What we accept

- Bug fixes (with a failing test that proves the bug)
- New lib (must follow the structure in `PROJECT_PLAN.md` §5)
- Documentation improvements
- Platform fixes (e.g. Windows-specific path in a Unix-only API)
- Performance improvements (with before/after benchmarks)

## What we don't accept

- ❌ LLM-generated code (PRs flagged as such will be closed)
- ❌ Silent API additions that overlap with existing functions
- ❌ "Modernization" PRs (renaming, reformatting without behavior change)
- ❌ Adding features "for the future" (YAGNI)
- ❌ New dependencies for trivial functionality
- ❌ Changes that break tests on the pinned Zig version

## Commit format

We don't enforce Conventional Commits strictly, but follow this shape:

```
<scope>: <one-line summary>

<body — explain the why, not the what>

<footer — references issues, breaking change notes>
```

Examples:
```
uuid: add parse() impl with 12 RED tests
cli: scaffold build.zig.zon, no public API yet
uuid: deprecate parseLenient in favor of parseStrict
```

## Public API change policy

This is the project's #1 contract. We do not break APIs casually.

| Change | Required |
|---|---|
| Add new function | ✅ OK at any time |
| Add optional parameter (with default) | ❌ Not allowed — add new function instead |
| Rename function | Major version bump + 1-release deprecation |
| Change parameter order | Major version bump |
| Change return type | Major version bump |
| Add new error to error set | Minor version OK (caller must handle it anyway) |
| Remove function | Major version bump + 2-minor deprecation cycle |
| Change behavior of existing function | Major version bump (rare — usually means a bug) |

When in doubt: **add a new function, deprecate the old one**.

## Changelog format

`Keep a Changelog`-style, per-package:

```markdown
## [0.2.0] - 2026-07-01

### Added
- `MyType.parseStrict(s)` — strict mode

### Changed
- `MyType.parse` is now deprecated, use `parseStrict` or `parseLenient`

### Fixed
- Off-by-one in buffer size calculation (#42)
```

## Test requirements

- All PRs must include tests for new code
- Tests must pass on the pinned Zig version (see `LTS-0.16`)
- Bug fixes must include a **failing test that reproduces the bug** (turns RED first)
- Coverage of edge cases is required for any function marked "robust" in the plan

## Review process

- Maintainer reviews every PR
- Review focuses on: does it follow the plan? are tests thorough? does it stay in scope?
- Reviewers may request changes; iterative review is normal
- Approval requires all CI checks passing

## License

By contributing, you agree your contributions are licensed under the project's MIT License.

## Questions?

Open an issue. The maintainer responds within a few days.

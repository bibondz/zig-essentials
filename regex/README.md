# `regex` — PCRE subset

> **Status:** planned (Tier 2 #5, see `../../ZIG_STD_LIB_AUDIT.md`)

## Why

Zig std has no regex. 90% of text-processing code needs it. Hand-writing a regex engine is non-trivial; this is a real gap, not a "nice to have".

## Scope (planned)

- PCRE2-compatible **subset** (not full PCRE):
  - Literals, `.`, `^`, `$`
  - Character classes `[abc]`, `[^abc]`, `\d`, `\w`, `\s`
  - Quantifiers `*`, `+`, `?`, `{n,m}`
  - Grouping `(...)`, alternation `|`
  - Non-greedy `*?`, `+?`
  - Anchors `\b`
- Linear-time guarantee (no catastrophic backtracking — use NFA/Thompson NFA, not recursive backtrack)
- UTF-8 input
- Capture groups (numbered only, no named)

## Non-goals (deliberate)

- ❌ Lookahead / lookbehind
- ❌ Backreferences
- ❌ Named groups
- ❌ Possessive quantifiers
- ❌ Unicode property classes (`\p{...}`)
- ❌ JIT compilation

## Stability promise

- API frozen at 0.1.0
- v0.1.0: subset above, replace, find all
- v0.2.0: capture groups
- v0.3.0: replace with backreference (\1, \2)

## Reference

See `ZIG_STD_LIB_AUDIT.md` §1, gap #1.

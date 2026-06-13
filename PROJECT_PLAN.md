# Project plan: zig-essentials

> Stable, explicit, minimal Zig libraries that should be in `std` but aren't.

---

## 1. Core principles (non-negotiable)

| # | Principle | What it means in practice |
|---|---|---|
| 1 | **Explicit** | No hidden allocations, no implicit behavior, every name says what it does. |
| 2 | **Robust** | Edge cases covered, fuzz tested, no `panic` in release. Errors return `error`. |
| 3 | **Practical** | Solves real developer pain. Not theoretical completeness. |
| 4 | **Stable** | Public API is a contract. Breaking it = major version event. |

## 2. Anti-patterns we reject (these are how Zig std gets a bad name)

- ❌ Silent API redesigns between minor versions
- ❌ "Rewrite it because we can" churn
- ❌ Breaking change bundled with a feature release
- ❌ Public types in flux
- ❌ Undocumented behavior changes
- ❌ Deprecate + remove in the same release

## 3. Versioning policy — LTS

### 3.1 LTS series
- **LTS-0.16** (active now) — pins to Zig **0.16.0**
- Future: **LTS-0.17** when Zig 0.17 stable releases

When a new Zig release ships, we evaluate compatibility. If the new release is stable, we add a new LTS series alongside. Old series enters maintenance, then EOL.

### 3.2 SemVer discipline
- **Major (X.0.0):** any breaking change to public API
- **Minor (0.X.0):** new features, no breaking change
- **Patch (0.0.X):** bug fixes only, no new features

### 3.3 Public API contract — frozen at 0.1.0
- Function signatures **never** change after stable release
- New parameters? **New function** (`parseStrict`, `parseLenient`, ...)
- Deprecation cycle: deprecate at 0.X → remove at 0.(X+2) **minimum**
- Renames / semantic changes / type changes = major version

### 3.4 LTS support matrix

| LTS | Zig version | Status | EOL |
|---|---|---|---|
| LTS-0.16 | 0.16.0 | **active** | when Zig 0.18 stable releases |
| LTS-0.17 | TBD | planned | — |

## 4. Repository structure

```
essentials/
├── README.md                  ← overview, points to this plan
├── PROJECT_PLAN.md            ← this file
├── CHANGELOG.md               ← global changelog
├── LTS-0.16                   ← marker: "this project is on LTS-0.16"
├── ZIG_STD_LIB_AUDIT.md       ← why these libs were chosen
├── uuid/                      ← v0.1.0-dev (in progress)
├── cli/                       ← planned
├── toml/                      ← planned
├── log/                       ← planned
├── regex/                     ← planned
├── websocket/                 ← planned
├── watcher/                   ← planned
└── tracing/                   ← planned
```

## 5. Per-package layout

```
<lib>/
├── build.zig.zon              ← pinned to LTS-0.15 (Zig 0.15.2)
├── build.zig                  ← minimal: `zig build test` works
├── README.md                  ← what + how + non-goals
├── CHANGELOG.md               ← per-package changelog
└── src/
    ├── <lib>.zig              ← public API
    └── <lib>_test.zig         ← tests (TDD: RED → GREEN → REFACTOR)
```

## 6. Build/test workflow

```bash
cd <lib>
zig build test        # run all tests for that lib
zig build             # build everything
```

- All packages use the same Zig version (pinned in `build.zig.zon` + `LTS-*` marker)
- CI matrix: linux-x86_64, linux-aarch64, macos-aarch64, windows-x86_64 — all on Zig 0.16.0
- No "works on my machine" — CI gate is mandatory

## 7. Contribution rules

These are rules for any future contributor (including the maintainer):

- **TDD:** test in same PR as impl. RED → GREEN → REFACTOR.
- **One concern per commit** — no "drive-by refactor" bundled with feature
- **Public API change** = new function OR major version bump (no in-place edits)
- **Changelog entry required** for every release
- **LLM-generated code:** not accepted (aligns with Zig org policy on Codeberg)
- **Code review** by human maintainer before merge

## 8. Roadmap

See `ZIG_STD_LIB_AUDIT.md` for the 9 verified gaps in Zig 0.17 std.

### Tier 1 — ship in this order
1. **uuid** — RFC 4122/9562 v4 + v7 (in progress)
2. **cli** — struct-based argument parser
3. **toml** — Cargo-grade config parser

### Tier 2
4. **log** — structured logger
5. **regex** — PCRE subset

### Tier 3
6. websocket
7. watcher
8. tracing

## 9. Non-goals (deliberate)

- ❌ Become a meta-package manager
- ❌ Provide EVERY format/parser in the world
- ❌ Wrap all C libraries
- ❌ Follow Zig std lib's API churn
- ❌ Add features "for the future" (YAGNI applies)
- ❌ Try to be "modern" — prefer stable over trendy

## 10. License + governance

- **License:** MIT (matches Zig std)
- **Maintainer:** single (the project owner)
- **PR policy:** open to community, **human-authored only** (no LLM)
- **Issue policy:** bug reports + clear feature requests welcome
- **Codeberg first** (aligns with Zig org's own migration)

## 11. Why "essentials"

The name says it: these are things that *should* be in std. We don't aim to be a kitchen-sink collection like Rust's `tokio` or Go's `x/...`. We aim to fill exactly the gaps in `lib/std` — and stop.

If a future Zig release includes one of our libs in std, we **deprecate ours** and point users to std. We don't fight upstream. We just bridge the gap until upstream arrives.

## 12. When Zig LTS changes (upgrade workflow)

This project is locked to Zig 0.16.0. When the next stable Zig release ships, we evaluate whether to:

- **A. Adopt new version as new LTS** (add `LTS-0.17` alongside, maintain both for transition)
- **B. Stay on LTS-0.16** (mark new version "planned LTS" until adoption is approved)
- **C. Skip version** (e.g. if 0.17 breaks too much, wait for 0.18)

**Decision criteria for adopting a new LTS:**
1. New Zig version is `stable` (not `-dev`/`-rc`) on ziglang.org download page
2. All `zig build test` in all libs pass on the new version
3. If API breaks: either fix in-place (minor cost) or add new LTS series (major cost)
4. Document the migration cost in `CHANGELOG.md`

**To refresh the gap audit when upgrading:**

See `ZIG_STD_LIB_AUDIT.md` §6 ("How to refresh this audit") for the full workflow.

TL;DR: use the installed std lib (no git clone), re-index 13 files into KB with new version label, re-verify 8 gaps, update doc. If a gap is now filled by std → deprecate the lib in essentials.

**The audit is a living document, not a snapshot.** It must be re-verified on every LTS bump.

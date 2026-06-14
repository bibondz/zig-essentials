# zig-essentials

Stable, explicit, minimal Zig libraries that should be in `std` but aren't.

> **Read first:** [PROJECT_PLAN.md](./PROJECT_PLAN.md) — design principles, versioning, roadmap, why this exists.
> **Read second:** [ZIG_STD_LIB_AUDIT.md](./ZIG_STD_LIB_AUDIT.md) — what's in std, what's missing, why these specific libs.
> **Read before contributing:** [CONTRIBUTING.md](./CONTRIBUTING.md) — TDD, no LLM, public API change policy.
> **Security issues:** [SECURITY.md](./SECURITY.md) — private reporting, not public issues.

## Status

| Lib | Version | Status |
|---|---|---|
| `uuid` | v0.1.0 | ✅ first stable |
| `cli` | v0.1.0 | ✅ first stable |
| `toml` | v0.1.0 | ✅ first stable |
| `log` | v0.1.0 | ✅ first stable |
| `regex`, `websocket`, `watcher`, `tracing` | — | planned |

## LTS

**LTS-0.16** — pinned to Zig **0.16.0**. See `LTS-0.16`.

## Quick start

```bash
# Pick a lib
cd uuid

# Run its tests
zig build test
```

## Principles (in one line each)

- **Explicit** — no hidden behavior
- **Robust** — fuzz-tested, no release panics
- **Practical** — real pain points only
- **Stable** — public API is a contract, breaking it is a major event

## License

MIT.

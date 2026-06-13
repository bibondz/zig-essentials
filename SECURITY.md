# Security policy

## Supported versions

This project is on **LTS-0.16** (Zig 0.16.0). We provide security fixes only for the active LTS series.

| Series | Status | Security fixes |
|---|---|---|
| LTS-0.16 (current) | active | ✅ yes |
| LTS-0.15 (if ever released) | planned | n/a |
| Older | none | ❌ no |

When we adopt a new LTS, the old series enters a brief overlap period (typically 1 minor release) for transition, then EOL.

## Reporting a vulnerability

**Please do not report security issues via public Git/Codeberg issues.**

For sensitive reports, use one of:

- **Email:** <maintainer email — fill in before publishing>
- **Codeberg security advisory:** (preferred once the project has a public home)

Include:
- Affected package + version
- Zig version you used
- Reproduction steps (minimal code if possible)
- Expected vs actual behavior
- Your assessment of impact (low/medium/high)

We aim to acknowledge within 7 days. Triage and fix time depend on severity.

## Severity classification

We use CVSS 3.1 informally:

| Severity | Examples | Response target |
|---|---|---|
| Critical | RCE, sandbox escape, unauthenticated data access | 24–72h |
| High | Auth bypass, data corruption, DoS via memory exhaustion | 1–2 weeks |
| Medium | Information disclosure (limited), DoS via resource use | next release |
| Low | Issues with no realistic exploit path | backlog |

## Disclosure policy

We follow **coordinated disclosure**:

1. Reporter contacts maintainer privately
2. Maintainer confirms and triages
3. Fix developed in a private branch
4. Fix released as a patch version
5. Public disclosure 7–14 days after fix release (or by mutual agreement)
6. Reporter credited in the changelog (unless they prefer anonymity)

## Out of scope

- Issues in upstream Zig std lib — report to [Zig project](https://codeberg.org/ziglang/zig)
- Issues in third-party dependencies — report to their maintainers
- Theoretical issues without a concrete exploit path

## Cryptography note

The `crypto` family in Zig std is what we use. We do not implement our own crypto. If you find an issue in our use of crypto, report it the same way as any other bug — but understand the actual crypto bug is in upstream Zig, not us.

## Recognition

Security reporters are credited in:
- The release notes for the fix
- This file (with permission)

Thank you for helping keep this project and its users safe.

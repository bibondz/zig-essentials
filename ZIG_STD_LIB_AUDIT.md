# Zig 0.16 std lib audit

**Date:** 2026-06-13
**Audited against:** Zig **0.16.0** std lib (installed: `C:/Users/Lenovo/scoop/apps/zig/0.16.0/lib/std/`)
**Pinned to LTS:** Zig **0.16.0** (`LTS-0.16` marker)
**Initial scope:** First audit was on `0.17.0-dev` (master) for forward-compat visibility. Re-verified on `0.16.0` (installed std lib, authoritative) — all 8 gaps confirmed identical across both versions. Only documentation/source path differs; gaps themselves are stable.
**Source:** Installed Zig 0.16.0 std lib (authoritative — not a git checkout, not a clone)
**Method:** Direct std lib inspection + `ctx_index` of 13 key files into FTS5 KB

---

## TL;DR

Std lib 0.16 ครบกว่าที่คนส่วนใหญ่คิดมาก — BigInt (4841 LoC), HTTP Server (803 LoC), zstd, argon2, tar/zip, post-quantum crypto มีครบ
**ของที่หายไปจริงๆ มีแค่ 8 ตัว** (essentials only, ไม่นับ nice-to-have)

**คำแนะนำ:** สร้าง lib เล็กๆ เติมช่องว่างเหล่านี้ — ไม่ fork, ไม่ contribute upstream, แค่ ship ให้ตัวเองใช้

---

## 1. The 8 gaps (essentials only — verified on 0.16.0)

| # | Gap | Verified by | Replacement hint |
|---|---|---|---|
| 1 | **Regex** | `find . -iname "*regex*"` → no results | เขียนเอง (PCRE subset), ใช้ NFA + backtrack |
| 2 | **CLI argument parser (flag/subcommand)** | `process/Args.zig` มี `iterate()` + `toSlice()` + `IteratorGeneral` (quote-aware string splitter) — แต่ **ไม่มี** flag/subcommand/positional แบบ clap | struct-based parser (style clap) |
| 3 | **TOML parser** | `find . -iname "*toml*"` → no results; ZON มีแต่ไม่ compat | ใช้ hand-written parser, RFC ชัด |
| 4 | **UUID v4 + v7** | `find . -iname "*uuid*"` → no results | ใช้ `std.Random` + RFC 4122 |
| 5 | **WebSocket** | ไม่มี protocol impl | RFC 6455 + frame codec |
| 6 | **Filesystem watcher** | ไม่มี inotify/FSEvents wrapper | per-platform: inotify, FSEvents, ReadDirectoryChangesW |
| 7 | **Structured logging** | `log.zig` text-only, มีแค่ `pub fn scoped` | JSON sink + level/filter middleware |
| 8 | **Tracing / spans** | ไม่มี OTel-style primitive | context propagation + export hooks |

### ของที่ "should have" แต่ **มีใน std แล้ว** (อย่าเขียนเอง)

- ✅ **BigInt** — `lib/std/math/big/int.zig` (4841 LoC + 4128 LoC tests)
- ✅ **HTTP Server** — `lib/std/http/Server.zig`
- ✅ **HTTP Client** — `lib/std/http/Client.zig`
- ✅ **zstd / lzma / xz** — `lib/std/compress/`
- ✅ **argon2 / scrypt / bcrypt** — `lib/std/crypto/`
- ✅ **post-quantum crypto** — `lib/std/crypto/ml_dsa.zig`, `ml_kem.zig`
- ✅ **tar / zip** — `lib/std/tar.zig`, `lib/std/zip.zig`
- ✅ **timezones** — `lib/std/tz/`
- ✅ **property-based testing** — `lib/std/testing/Smith.zig`
- ✅ **JSON (static + dynamic + streaming)** — `lib/std/json/`
- ✅ **TLS client** — `lib/std/crypto/tls/Client.zig`
- ✅ **ZON (Zig's own config format)** — `lib/std/zon/parse.zig` (3575 LoC)

---

## 2. Tier priority

### 🟢 Tier 1 — เริ่มตรงนี้
1. **CLI argument parser** — 1 ไฟล์, scope ชัด, ใช้ทุก tool
2. **UUID v4 + v7** — RFC 4122, ~300 lines, ship ได้ใน 1–2 วัน
3. **TOML parser** — Cargo-grade, สำคัญกับ tool ที่อ่าน config

### 🟡 Tier 2 — ต่อจากนั้น
4. **Structured logging** — แทน text log
5. **Regex** — ใหญ่กว่า, แต่ killer feature สำหรับ adoption

### 🔴 Tier 3 — ทำทีหลัง
6. WebSocket
7. Filesystem watcher
8. Tracing/spans

---

## 3. Known TODOs / incomplete ใน std เอง

จาก `grep -rE "TODO|FIXME|UNIMPLEMENTED|@panic\(.unimplemented"`:

| Location | Impact | Workaround |
|---|---|---|
| `compress/lzma.zig:700` | LZMA encoder ยังไม่เสร็จ | ใช้ zstd แทน (มีใน std) |
| `compress/xz/Decompress.zig` | XZ decompress มี edge case TODO | ใช้ zstd แทน |
| `crypto/tls/Client.zig` | key_update overflow, server-side closures | หลีกเลี่ยง post-handshake ที่ต้อง re-key |
| `debug/Dwarf/expression.zig` | DWARF expression evaluator ไม่เสร็จ | debugger user เจ็บ, dev tool ไม่กระทบ |
| `Build/Step/Options.zig:372` | "write declarations" | build system feature หาย |
| `c/openbsd.zig:83` | va_list support ไม่มี | OpenBSD C interop จำกัด |

**Insight:** ของที่ "production code" ใช้ (fs, JSON, hash, http, math/big, Io) — แทบไม่มี TODO
**Incomplete** เป็น edge/peripheral (debug info, exotic compression, niche OS)

---

## 4. Maturity signal

```
Total std lib: 464,024 LoC
Top 10 user-facing modules:
  19,053  Io/Threaded.zig         ← I/O rewrite (ใหม่)
  13,554  zig/AstGen.zig
   5,132  mem.zig
   4,841  math/big/int.zig
   3,825  Target.zig
   3,575  zon/parse.zig
   3,535  Io.zig
   3,599  crypto/ml_dsa.zig
   3,572  crypto/pcurves/p384/p384_64.zig
   5,211  Target/x86.zig
```

`Io/` module ใหม่หมด — `Dispatch.zig` (5k), `Uring.zig` (6.1k), `Kqueue.zig`, `Threaded.zig` (19k) — คือ I/O rewrite ครั้งใหญ่ของ Zig

---

## 5. Knowledge base access

13 ไฟล์ถูก index เข้า context-mode FTS5 KB แล้ว — ใช้ `ctx_search(queries: [...], source: "<label>")`:

> **Important:** `source` ต้องเป็น **exact label** ไม่ใช่ wildcard (`zig-0.16-std:*` ไม่ทำงาน)

| Source label | ใช้เมื่อถามว่า |
|---|---|
| `zig-0.16-std:root` | "มี pub const อะไรบ้างใน std" |
| `zig-0.16-std:process-args` | "Args API ทำอะไรได้" |
| `zig-0.16-std:math-big-int` | "BigInt init/arithmetic" |
| `zig-0.16-std:zon-parse` | "ZON format spec" |
| `zig-0.16-std:log` | "log API scope level" |
| `zig-0.16-std:http-server` | "HTTP server connection lifecycle" |
| `zig-0.16-std:json-static` | "JSON deserialize to struct" |
| `zig-0.16-std:crypto-argon2` | "password hash API" |
| `zig-0.16-std:io-new` | "Io.Reader/Writer pattern" |
| `zig-0.16-std:mem` | "Allocator API" |
| `zig-0.16-std:array-list` | "ArrayList unmanaged API" |
| `zig-0.16-std:hash-map` | "StringHashMap usage" |
| `zig-0.16-std:testing-smith` | "property-based testing" |

ตัวอย่าง query ที่ใช้บ่อย:
```
"BigInt from string"
"args toSlice usage"
"http server read request"
"json parse to struct"
"argon2 hash verify"
```

---

## 6. How to refresh this audit

เมื่อ Zig 0.16 → 0.17 stable ออก (หรือ patch update):

1. Update Zig version (e.g. `scoop install zig` or your package manager)
2. Re-index ใน KB (13 calls, labels `zig-<ver>-std:*`):
   ```zig
   ctx_index(path: "C:/Users/Lenovo/scoop/apps/zig/<ver>/lib/std/std.zig", source: "zig-<ver>-std:root")
   // ... and 12 more for the files in the table above
   ```
3. Re-verify the 8 gaps (run `find` for regex/toml/uuid/websocket/watcher/tracing keywords in the new std lib)
4. Update this doc:
   - Section 1: gaps table (add/remove if anything changed)
   - Section 2: "use this" list (verify BigInt, HTTP server, etc. still exist)
   - Section 3: known TODOs (may have changed)
   - Header: bump "Audited against" to new version
5. If a gap is now filled by std → deprecate the corresponding lib in essentials (don't ship it)
6. Commit `ZIG_STD_LIB_AUDIT.md` ใหม่เข้า repo

**No git clone needed** — installed std lib is the authoritative source.

เมื่อเริ่มเขียน lib ใหม่:
1. Add ไฟล์ของคุณเองเข้า KB: `ctx_index(path: "essentials/<lib>/src/<lib>.zig", source: "<lib>:main")`
2. Query cross-ref ระหว่าง KB ของ std กับ KB ของ lib คุณ

---

## 7. Next step

**Tier 1 #1: CLI argument parser** (uuid v0.1.0-dev already done; cli is next)

เมื่อพร้อม:
- เปิด session ใหม่
- บอก: "เริ่ม CLI parser ตาม audit"
- ผมจะร่าง API sketch + non-goals + test plan ให้

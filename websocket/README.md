# `websocket` — RFC 6455 client + server

> **Status:** planned (Tier 3 #6, see `../../ZIG_STD_LIB_AUDIT.md`)

## Why

Zig std has `http/Server.zig` and `http/Client.zig` but no WebSocket layer. Real-time services need it.

## Scope (planned)

- RFC 6455 frame codec (text + binary, masked from client, no fragmentation at first)
- Per-message deflate extension (RFC 7692) — opt-in
- Ping/pong with auto-reply
- Server-side: integrate with `http.Server`
- Client-side: integrate with `http.Client`

## Non-goals (deliberate)

- ❌ Legacy versions (Hybi 00–17, Hixie 75/76) — RFC 6455 only
- ❌ Subprotocol negotiation beyond "give me a string, accept if in list"
- ❌ Auto-reconnect (caller decides)
- ❌ WSS (TLS) tunnel — use `http.Client`'s TLS

## Stability promise

- API frozen at 0.1.0
- v0.1.0: server + client, text/binary frames
- v0.2.0: per-message deflate
- v0.3.0: fragmentation, continuation frames

## Reference

See `ZIG_STD_LIB_AUDIT.md` §1, gap #5.

# `tracing` — OpenTelemetry-style spans

> **Status:** planned (Tier 3 #8, see `../../ZIG_STD_LIB_AUDIT.md`)

## Why

Zig std has error return traces (good) but no span / context propagation / OpenTelemetry primitives. For distributed systems, you need this.

## Scope (planned)

- Span lifecycle: start, end, child
- Context propagation (W3C traceparent format)
- Attributes (key-value)
- Events (timestamped, with attributes)
- Exporter interface (OTLP, Jaeger, console — pick one for v0.1.0)

## Non-goals (deliberate)

- ❌ Full OpenTelemetry spec (subset that matters for HTTP/JSON-RPC)
- ❌ Metrics (separate concern — `metrics` lib if ever needed)
- ❌ Logs (use `log` lib, structured)
- ❌ Async context across executors (caller passes Context explicitly)

## Stability promise

- API frozen at 0.1.0
- v0.1.0: in-process spans + console exporter
- v0.2.0: OTLP HTTP exporter
- v0.3.0: W3C traceparent

## Reference

See `ZIG_STD_LIB_AUDIT.md` §1, gap #8.

# YFinance.jl — Design Audit Report

## 1. Executive Summary

This audit covers the complete restructuring of YFinance.jl from a Dict-based, loosely-typed API to a production-quality Julia package with typed return structs, minimal dependencies, and comprehensive test coverage.

---

## 2. Key Problems Identified & Solutions

### 2.1 Type Instability (Critical)

**Problem:** All functions returned `OrderedDict{String, Union{String, Vector{DateTime}, Vector{Float64}}}` or `OrderedDict{String, Any}`. This defeats Julia's JIT compiler — every field access requires runtime type dispatch.

**Solution:** Introduced typed structs:
- `PriceData` — OHLCV with concrete `Vector{Float64}` fields
- `DividendData` — timestamp + dividend vectors
- `SplitData` — timestamp + numerator/denominator/ratio
- `OptionChain` / `OptionContract` — fully typed option data

**Impact:** Field access goes from ~50ns (Dict + dynamic dispatch) to ~1ns (struct field load). More importantly, downstream code can be compiled optimally.

**Reference:** [Julia Performance Tips - Avoid fields with abstract types](https://docs.julialang.org/en/v1/manual/performance-tips/#Avoid-fields-with-abstract-type)

### 2.2 Excessive Dependencies

**Problem:** `OrderedCollections.jl` was a runtime dependency used only for Dict ordering. `PrecompileTools` added complexity.

**Solution:** Removed both. Typed structs don't need ordered dicts — field order is defined at compile time. Dict is only used for `get_fundamentals` and `get_quote_summary` where the schema is truly dynamic.

### 2.3 Connection Pool Corruption After Rate Limiting

**Problem:** The persistent `Downloads.Downloader` gets into a bad state after receiving HTTP 429 responses. Subsequent requests hang or fail indefinitely.

**Solution:** Reset `_SESSION.downloader = nothing` on 429, forcing a new connection pool on next request. Combined with exponential backoff (5 retries, 2s base delay).

### 2.4 Volume Auto-Adjust Bug

**Problem:** Volume was multiplied by `adjclose/close` ratio. This is backwards — when a stock splits 2:1, historical volume should be halved to normalize, not doubled.

**Solution:** Volume is now divided by the adjustment ratio: `vol_v[i] /= ratio[i]`

### 2.5 File Naming & Organization

**Problem:** Mixed conventions: `Proxy_Auth.jl`, `QuoteSummary.jl`, `News_Search.jl`. Not idiomatic Julia.

**Solution:** All lowercase, short, descriptive:
```
types.jl, headers.jl, network.jl, tables.jl, proxy.jl,
validate.jl, prices.jl, summary.jl, fundamentals.jl,
options.jl, search.jl, news.jl
```

### 2.6 Proxy Support Was Broken

**Problem:** `set_proxy!` stored the URL but `_raw_request` never passed it to `Downloads.request`.

**Solution:** Added conditional `proxy` kwarg to the `Downloads.request` call.

---

## 3. Design Patterns Applied

### 3.1 Struct-of-Arrays (Column-Major Layout)

`PriceData` stores one vector per field rather than one struct per row. This is:
- Cache-friendly for column operations (mean, std, etc.)
- Natural for Tables.jl interface
- Matches Julia's column-major memory layout philosophy

### 3.2 Singleton Session with Lock

`YahooSession` is a mutable singleton with `ReentrantLock` for thread safety. This avoids:
- Passing session objects through every function
- Race conditions on cookie/crumb state
- Connection pool proliferation

### 3.3 Layered Request Architecture

```
User API (get_prices, get_options, ...)
  └── _yahoo_get (error handling, warnings)
       └── _request (retry + rate limit + session)
            └── _raw_request (bare HTTP, connection pool)
```

Each layer has a single responsibility. Retry logic doesn't leak into business logic.

### 3.4 Tables.jl Protocol

All primary data types implement `Tables.columnaccess` protocol:
- Zero-copy: just returns the struct's vectors
- Schema-aware: `Tables.schema` provides compile-time type info
- Composable: works with any Tables.jl sink (DataFrames, CSV, Arrow, etc.)

### 3.5 Fail-Safe Defaults

All public functions default to `throw_error=false`, returning empty typed structs with appropriate warnings. This follows the principle of least surprise for interactive/REPL use.

---

## 4. Why Not Full Struct Returns for Everything?

**Fundamentals** (`get_fundamentals`): User selects from 300+ possible line items. Creating a struct with 300 optional fields would be worse than a Dict. The data is inherently dynamic.

**Quote Summary** (`get_quote_summary`): 34 modules, each with different schemas. The raw return is a JSON blob. Accessor functions (like `earnings_per_share`) extract and validate the structure.

**Decision:** Use typed structs where the schema is fixed and predictable (prices, options). Use Dict where the schema is user-defined or varies per request.

---

## 5. Performance Characteristics

| Operation | Bottleneck | Optimization |
|-----------|-----------|-------------|
| HTTP request | Network I/O | Connection pool reuse |
| JSON parsing | CPU | `JSON.parse` (C-backed) |
| Data access | Type dispatch | Typed structs (zero-cost) |
| Rate limiting | Throttle delay | 0.5s minimum interval |
| Session auth | Two HTTP calls | Lazy init, cached until 401/403 |

---

## 6. Remaining Considerations

1. **Thread-safety for bulk operations**: `valid_symbols(["A", "B", ...])` calls sequentially. Could use `asyncmap` for parallel validation.
2. **Streaming for large datasets**: Minute data chunking works but could benefit from lazy iteration.
3. **Caching**: Frequently-accessed data (fundamentals, quote summary) could be cached with TTL.

---

## 7. Code Quality Validation

Validated with:
- **Aqua.jl** — No unbound type parameters, no stale dependencies, no ambiguities
- **JET.jl** — Static analysis for type inference issues

Both are used in tests but NOT runtime dependencies.

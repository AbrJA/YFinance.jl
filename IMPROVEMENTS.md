# YFinance.jl — Architecture & Improvements

## Design Decisions

### Why NOT Multithreading/Async

This library intentionally uses **sequential, rate-limited requests**:

1. **Bottleneck is I/O + rate limits, not CPU** — Yahoo Finance aggressively rate-limits (429). Parallel requests would trigger limits faster.
2. **Shared session state** — Cookie/crumb auth requires serialized access. Adding concurrent request queues adds complexity without benefit.
3. **Users control parallelism** — Julia's broadcasting (`get_prices.(symbols)`) + `@threads`/`asyncmap` give users control when they need it.
4. **Reliability over speed** — For a data retrieval library, one reliable request is better than 10 racy ones.

### Why Downloads.jl (not HTTP.jl)

| Factor | HTTP.jl | Downloads.jl |
|--------|---------|--------------|
| Availability | External package | Julia stdlib (always present) |
| Dependencies | ~15+ transitive | Zero |
| Breaking changes | Frequent | Tied to Julia version |
| TLS/Proxy | Own implementation | Battle-tested libcurl |

### Dependency Audit

| Package | Purpose | Required? |
|---------|---------|-----------|
| `Base64` | Proxy auth encoding | Yes (stdlib, zero cost) |
| `Dates` | Timestamp handling | Yes (stdlib, essential) |
| `Downloads` | HTTP requests | Yes (stdlib, core networking) |
| `JSON3` | JSON parsing | Yes (fast, StructTypes-based) |
| `OrderedCollections` | Stable column order for DataFrame compat | Yes (design choice) |
| `PrecompileTools` | TTFX reduction | Yes (precompile workloads) |
| ~~`Random`~~ | Was used only for `rand(HEADERS)` | **Removed** — `rand` is in Base |

---

## Completed Improvements

### 1. HTTP.jl → Downloads.jl Migration ✅
Replaced all HTTP.jl calls with Downloads.jl (stdlib). Eliminates dependency resolution failures.

### 2. YahooSession Singleton Architecture ✅
Thread-safe mutable struct with `ReentrantLock`, `const` fields for configuration, lazy initialization.

### 3. Rate Limiting (300ms throttle) ✅
Minimum interval between requests prevents 429 errors. Configurable via `min_request_interval`.

### 4. Retry with Exponential Backoff ✅
3 attempts, 1.5s base delay. Handles 429, 401/403 (with session renewal), and network errors.

### 5. Connection Pooling ✅
Persistent `Downloads.Downloader` instance reuses TCP connections across requests. Reduces latency.

### 6. Standardized Error Handling (`_yahoo_get`) ✅
Single entry point for all Yahoo requests. Consistent error messages, warn-or-throw pattern.

### 7. Immutable Data Structs ✅
`YahooSearchItem`, `NewsItem`, `YahooSearch`, `YahooNews` are now `struct` (not `mutable struct`).
Proper `AbstractVector` interface with `IndexStyle`, `size`, `getindex`.

### 8. Dependency Cleanup ✅
Removed `Random` (unused — `rand` is in Base). Reduced external deps to 3 (JSON3, OrderedCollections, PrecompileTools).

### 9. Clean Module Exports ✅
Organized exports by category. Removed re-exports of Base functions (`size`, `getindex`, `show`).
Removed dead code (unused macros, legacy globals that served no purpose).

### 10. Enhanced Test Suite ✅
- Unit tests for internal utilities (URL encoding, date conversion, response processing)
- Input validation tests (invalid intervals, markets, languages, items)
- Proxy configuration tests
- Integration tests with edge cases (invalid symbols, old dates, non-US markets)
- Proper `sleep()` intervals for rate limiting

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Public API                                             │
│  get_prices, get_Options, get_Fundamental, etc.         │
├─────────────────────────────────────────────────────────┤
│  _yahoo_get(url, symbol)                                │
│  Standardized request + JSON parse + error handling     │
├─────────────────────────────────────────────────────────┤
│  _request(url)                                          │
│  Rate-limited + retry + session auto-renewal            │
├─────────────────────────────────────────────────────────┤
│  _raw_request(url)                                      │
│  Downloads.request with persistent Downloader           │
├─────────────────────────────────────────────────────────┤
│  YahooSession (const _SESSION)                          │
│  Cookie, crumb, headers, proxy, rate limit config       │
│  Thread-safe via ReentrantLock                          │
└─────────────────────────────────────────────────────────┘
```

---

## Remaining / Future Improvements

### 1. Response Type System (Medium)
Define typed result structs (`PriceResult`, `OptionChain`, etc.) instead of `OrderedDict{String,Any}`.
Would enable dispatch, better documentation, and IDE autocompletion.
**Trade-off**: Breaks backward compat with DataFrame pipe pattern (`result |> DataFrame`).

### 2. Mock-Based Unit Tests (Low)
Separate network tests from data processing tests using recorded JSON fixtures.
Would make CI faster and more reliable.

### 3. Environment Variable Proxy Fallback (Low)
Falls back to `HTTP_PROXY`/`HTTPS_PROXY` env vars when no explicit proxy is configured.
Downloads.jl/libcurl already respects these, so this may already work implicitly.

### 4. Configurable Session (Low)
Allow users to override rate limit interval, retry count, etc.:
```julia
YFinance.configure!(min_interval=0.5, max_retries=5)
```

### 5. Streaming/Pagination (Low)
For `get_all_symbols` or bulk operations, streaming results instead of loading all into memory.
Not critical given typical result sizes.

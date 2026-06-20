# YFinance.jl — Improvements & Recommendations

## Completed Improvements

### 1. HTTP.jl → Downloads.jl Migration ✅

| Factor | HTTP.jl | Downloads.jl |
|--------|---------|--------------|
| Availability | External package (can fail to resolve) | Julia stdlib since v1.6 — always present |
| Dependency weight | ~15+ transitive dependencies | Zero extra dependencies |
| Compat issues | Frequent breaking changes between major versions | Tied to Julia version, stable API |
| Maintenance | Must track upstream breaking changes | Maintained by Julia core team |
| TLS/Proxy | Own implementation | Uses battle-tested libcurl |

The root cause of the package being broken was HTTP.jl failing to resolve in the Manifest (incompatible compat bound `HTTP = "1.2"` with Julia 1.12). Switching to Downloads.jl eliminates this class of problems entirely.

### 2. Centralized Network Layer with YahooSession ✅

Implemented a `YahooSession` mutable singleton struct in `src/network.jl` that manages:
- Cookie and crumb storage
- Request headers
- Proxy settings
- Thread-safe access via `ReentrantLock`
- Lazy initialization (session created on first request)
- Automatic session renewal on 401/403 errors

```julia
mutable struct YahooSession
    cookie::String
    crumb::String
    header::Vector{Pair{String,String}}
    proxy::String
    proxy_auth::String
    last_request_time::Float64
    min_request_interval::Float64  # 0.3s default
    max_retries::Int               # 3 default
    retry_base_delay::Float64      # 1.5s default
    initialized::Bool
    lock::ReentrantLock
end
```

### 3. Rate Limiting / Request Throttling ✅

Built-in throttling with a configurable minimum interval (300ms default) between requests. Prevents Yahoo Finance 429 rate-limit errors automatically.

### 4. Retry Logic with Exponential Backoff ✅

All requests automatically retry up to 3 times with exponential backoff (1.5s base delay). Handles:
- HTTP 429 (Too Many Requests)
- HTTP 401/403 (triggers session renewal before retry)
- Network errors (transient connectivity issues)

### 5. Standardized Error Handling via `_yahoo_get()` ✅

All endpoint modules now use a single `_yahoo_get(url)` function that:
- Ensures the session is initialized
- Makes the rate-limited, retried request
- Parses the JSON response
- Returns a standardized `(success::Bool, data)` tuple
- Handles both JSON and plain-text error bodies gracefully

This eliminated duplicated try/catch blocks across all endpoint files.

### 6. Backward-Compatible API ✅

All public-facing functions maintain their original signatures. Internal refactoring is transparent to users. Legacy globals (`_PROXY_SETTINGS`, `_COOKIE`, `_CRUMB`) are maintained as thin wrappers.

---

## Remaining Improvements

### 1. Test Suite Hardening (Medium Priority)

The test suite (59 tests, all passing) relies entirely on live API calls. Improvements:

- **Mock responses for unit tests**: Test data processing logic separately from network calls
- **Retry-aware test helpers**: Wrap API calls in test utilities that tolerate transient failures
- **CI-friendly configuration**: Add environment variable to increase sleep intervals in CI
- **Separate integration vs unit tests**: Unit tests should be fast and network-independent

### 2. Connection Pooling / Downloader Reuse (Low Priority)

Currently each request creates a new connection. Using a persistent `Downloads.Downloader` instance could improve latency for bulk operations:

```julia
const _DOWNLOADER = Ref{Union{Nothing,Downloads.Downloader}}(nothing)

function _get_downloader()
    if isnothing(_DOWNLOADER[])
        _DOWNLOADER[] = Downloads.Downloader()
    end
    return _DOWNLOADER[]
end
```

### 3. Proxy Support via Environment Variables (Low Priority)

Downloads.jl (libcurl) natively supports `HTTP_PROXY`/`HTTPS_PROXY` environment variables. Consider falling back to these when no explicit proxy is configured:

```julia
function _get_effective_proxy()
    if !isempty(_SESSION.proxy)
        return _SESSION.proxy
    end
    return get(ENV, "HTTPS_PROXY", get(ENV, "HTTP_PROXY", ""))
end
```

### 4. Type Stability Improvements (Low Priority)

Several functions return `OrderedDict{String, Any}` which is type-unstable. Consider:
- Defining result structs for common return types (e.g., `PriceData`, `OptionChain`)
- Using parametric types where possible
- Documenting return structures for downstream type inference

### 5. Documentation Updates (Low Priority)

- Update docs to reflect the removal of the HTTP.jl dependency
- Document the cookie/crumb authentication flow
- Add troubleshooting section for rate limiting issues
- Update `VersionChanges.md` with the architectural changes
- Document thread-safety guarantees

### 6. Julia Version Compat (Low Priority)

The `[compat]` section sets `julia = "1.6"`. Consider bumping to `julia = "1.9"` or later since Downloads.jl has improved significantly in newer versions and the user base has largely migrated.

---

## Architecture Summary

```
┌─────────────────────────────────────────────────┐
│  Public API (get_prices, get_Options, etc.)      │
├─────────────────────────────────────────────────┤
│  _yahoo_get(url) — standardized request+parse   │
├─────────────────────────────────────────────────┤
│  _request(url) — rate-limited + retry + renew   │
├─────────────────────────────────────────────────┤
│  _raw_request(url) — Downloads.request wrapper  │
├─────────────────────────────────────────────────┤
│  YahooSession singleton — state + config        │
└─────────────────────────────────────────────────┘
```

All network logic is centralized in `src/network.jl`. Endpoint modules are thin layers that build URLs and process JSON responses.
4. **Session management** — thread-safe, auto-renewing authentication

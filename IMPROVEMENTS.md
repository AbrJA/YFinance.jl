# YFinance.jl — Improvements & Recommendations

## Completed: HTTP.jl → Downloads.jl Migration

### Why Downloads.jl is better for this package

| Factor | HTTP.jl | Downloads.jl |
|--------|---------|--------------|
| Availability | External package (can fail to resolve) | Julia stdlib since v1.6 — always present |
| Dependency weight | ~15+ transitive dependencies | Zero extra dependencies |
| Compat issues | Frequent breaking changes between major versions | Tied to Julia version, stable API |
| Maintenance | Must track upstream breaking changes | Maintained by Julia core team |
| TLS/Proxy | Own implementation | Uses battle-tested libcurl |

The root cause of the package being broken was HTTP.jl failing to resolve in the Manifest (incompatible compat bound `HTTP = "1.2"` with Julia 1.12). Switching to Downloads.jl eliminates this class of problems entirely.

### What changed
- Replaced all `HTTP.get()` calls with a custom `_request()` wrapper over `Downloads.request()`
- Cookie management is now handled manually via request/response headers
- Query parameters are built manually via `_build_url()`
- Added `_parse_yahoo_error()` for robust error body parsing (handles both JSON and plain-text error responses)
- All endpoints now pass cookies (Yahoo now requires authentication for most endpoints)

---

## Recommended Improvements

### 1. Rate Limiting / Request Throttling (High Priority)

Yahoo Finance aggressively rate-limits requests (HTTP 429). The package needs built-in throttling.

**Suggestion:**
```julia
const _LAST_REQUEST_TIME = Ref(0.0)
const _MIN_REQUEST_INTERVAL = 1.0  # seconds

function _throttled_request(url; kwargs...)
    elapsed = time() - _LAST_REQUEST_TIME[]
    if elapsed < _MIN_REQUEST_INTERVAL
        sleep(_MIN_REQUEST_INTERVAL - elapsed)
    end
    _LAST_REQUEST_TIME[] = time()
    return _request(url; kwargs...)
end
```

### 2. Retry Logic with Exponential Backoff (High Priority)

When hitting 429 errors, the package should automatically retry with backoff instead of returning empty results.

**Suggestion:**
```julia
function _request_with_retry(url; max_retries=3, kwargs...)
    for attempt in 1:max_retries
        try
            return _request(url; kwargs...)
        catch e
            if e isa ResponseError && e.status == 429 && attempt < max_retries
                sleep(2^attempt)  # exponential backoff: 2s, 4s, 8s
                continue
            end
            rethrow()
        end
    end
end
```

### 3. Better Cookie/Session Management (Medium Priority)

Currently, `_set_cookies_and_crumb()` uses global variables (`_COOKIE`, `_CRUMB`, `_HEADER`). This has issues:
- Not thread-safe
- No cookie expiration tracking
- No automatic renewal on 401/403

**Suggestion:** Create a `YahooSession` struct:
```julia
mutable struct YahooSession
    cookie::Dict{String,String}
    crumb::String
    header::Dict{String,String}
    last_renewed::Float64
    lock::ReentrantLock
end
```

### 4. Test Suite Improvements (Medium Priority)

The test suite makes rapid-fire API calls that trigger rate limiting. Improvements needed:

- Add longer `sleep()` intervals between test sections (5-10s instead of 2s)
- Use `@testset` with `try-catch` around API calls to handle transient failures gracefully
- Add a test utility that retries on 429 errors
- Consider mocking API responses for unit tests (test data processing separately from network calls)
- The precompilation workload already tests `_process_response` — extend this pattern

### 5. Connection Pooling / Session Reuse (Low Priority)

Currently each request creates a new connection. Using a persistent `Downloads.Downloader` instance could improve performance:

```julia
const _DOWNLOADER = Ref{Union{Nothing,Downloads.Downloader}}(nothing)

function _get_downloader()
    if isnothing(_DOWNLOADER[])
        _DOWNLOADER[] = Downloads.Downloader()
    end
    return _DOWNLOADER[]
end
```

### 6. Proxy Support via Environment Variables (Low Priority)

The current proxy implementation uses a custom `_PROXY_SETTINGS` struct. Downloads.jl (libcurl) natively supports `HTTP_PROXY`/`HTTPS_PROXY` environment variables. Consider supporting both:

```julia
function _get_effective_proxy()
    if !isnothing(_PROXY_SETTINGS[:proxy])
        return _PROXY_SETTINGS[:proxy]
    end
    return get(ENV, "HTTPS_PROXY", get(ENV, "HTTP_PROXY", nothing))
end
```

### 7. Type Stability Improvements (Low Priority)

Several functions return `OrderedDict{String, Any}` which is type-unstable. Consider using parametric types or documented return structures to enable better type inference downstream.

### 8. Error Handling Consistency (Medium Priority)

Some functions (e.g., `get_Fundamental`) don't handle non-JSON error responses gracefully. The `_parse_yahoo_error` helper should be used consistently across all endpoints.

### 9. Documentation Updates (Low Priority)

- Update docs to reflect the removal of the HTTP.jl dependency
- Document the cookie/crumb authentication requirement
- Add troubleshooting section for rate limiting issues
- Update `VersionChanges.md` with the Downloads.jl migration

### 10. Julia Version Compat (Low Priority)

The `[compat]` section sets `julia = "1.6"` but the code uses features available since 1.6. Consider bumping to `julia = "1.9"` or later since Downloads.jl has improved significantly in newer versions.

---

## Summary

The most impactful improvements (in priority order):
1. **Rate limiting/throttling** — prevents 429 errors automatically
2. **Retry with backoff** — graceful recovery from transient failures
3. **Test suite hardening** — reliable CI without flaky API-dependent tests
4. **Session management** — thread-safe, auto-renewing authentication

# YFinance.jl v1.0 — Implementation Tracker

## Design Principles
- Julia naming conventions (lowercase, underscores, `!` for mutating, `is_` for predicates)
- No backward compatibility aliases
- `const` for all module-level constants
- No redundant HTTP requests (remove pre-validation)
- Typed returns with Tables.jl interface
- Minimal dependencies, clean code

---

## Implementation Plan (ranked by impact/complexity)

### Phase 1: Cleanup & Dead Code Removal
| # | Task | Status | Notes |
|---|------|--------|-------|
| 1 | Remove `aliases.jl` — rename originals directly | ✅ | Renamed functions in source files directly |
| 2 | Remove `cookie_and_crumb.jl` — dead wrappers | ✅ | Moved `_rand_header` to network.jl |
| 3 | Remove `ESG.jl` reference from YFinance.jl | ✅ | Was already commented out |
| 4 | Remove `get_all_symbols` (dumbstockapi.com) | ✅ | Removed entire function + MARKETS const |
| 5 | Remove `_make_headers` dead code from network.jl | ✅ | |
| 6 | Remove `sink_prices_to` from Prices.jl | ✅ | Tables.jl replaces this |
| 7 | Remove `_PROXY_SETTINGS` global (use session) | ✅ | Proxy state in _SESSION only |
| 8 | Remove PrecompileTools workload | ✅ | Removed dep from Project.toml too |
| 9 | Remove extensions (`ext/`) and weak deps | ✅ | Deleted ext/ dir, removed from Project.toml |

### Phase 2: Naming & Constants
| # | Task | Status | Notes |
|---|------|--------|-------|
| 10 | Rename `get_Options` → `get_options` | ✅ | |
| 11 | Rename `get_Fundamental` → `get_fundamentals` | ✅ | |
| 12 | Rename `get_quoteSummary` → `get_quote_summary` | ✅ | |
| 13 | Rename `eps` → `earnings_per_share` | ✅ | No longer shadows Base.eps |
| 14 | Rename `validate_symbol` → `is_valid_symbol` | ✅ | |
| 15 | Add `const` to all module-level constants | ✅ | HEADERS, FUNDAMENTAL_TYPES, FUNDAMENTAL_INTERVALS, QUOTE_SUMMARY_ITEMS |
| 16 | Rename types: `YahooSearch` → `SearchResults`, etc. | ✅ | Also YahooSearchItem→SearchResult, YahooNews→NewsResults |
| 17 | Fix `_BASE_URL_` trailing underscore | ✅ | Now `_BASE_URL` |

### Phase 3: Behavioral Fixes
| # | Task | Status | Notes |
|---|------|--------|-------|
| 18 | Remove double-validation (pre-request symbol checks) | ✅ | Removed from get_options, get_quote_summary, get_fundamentals |
| 19 | Fix proxy support (pass URL to Downloads.request) | ⬜ | |
| 20 | Reduce headers.jl to 5 modern browser profiles | ⬜ | |
| 21 | Fix volume autoadjust bug in Prices.jl | ⬜ | |
| 22 | Fix typos ("empy", "There are is no", "1x") | ⬜ | |

### Phase 4: Architecture
| # | Task | Status | Notes |
|---|------|--------|-------|
| 23 | Restructure file layout (types.jl, constants.jl, session.jl, request.jl) | ⬜ | |
| 24 | Typed return structs with Tables.jl interface | ⬜ | |
| 25 | Reduce QuoteSummary boilerplate (macro or generation) | ⬜ | |
| 26 | Fix type instability (typed arrays in Options, Fundamental) | ⬜ | |

### Phase 5: Testing & Docs
| # | Task | Status | Notes |
|---|------|--------|-------|
| 27 | Rewrite tests for new API | ✅ | 118 tests passing (all new names) |
| 28 | Update README.md | ✅ | Complete rewrite with new API |
| 29 | Update docs/ | ⬜ | |

---

## Work Log

| Date | Task # | Description | Commit |
|------|--------|-------------|--------|
| 2026-06-22 | 1-18, 27-28 | Phase 1+2 complete: removed aliases, dead code, extensions, PrecompileTools; renamed all functions/types/constants to Julia conventions; removed pre-validation; rewrote tests and README | pending |

---

## Final Public API (target)

### Functions
```julia
get_prices(symbol; kwargs...)       # OHLCV price data
get_dividends(symbol; kwargs...)    # Dividend history
get_splits(symbol; kwargs...)       # Stock split history
get_options(symbol; kwargs...)      # Options chain
get_fundamentals(symbol; kwargs...) # Financial statements
get_quote_summary(symbol; kwargs...)# Quote summary data
search_symbols(query; kwargs...)    # Symbol search
search_news(query; kwargs...)       # News search
is_valid_symbol(symbol)             # Boolean check
valid_symbols(symbols)              # Filter valid ones
set_proxy!(url; kwargs...)          # Set proxy (mutating)
clear_proxy!()                      # Clear proxy (mutating)
```

### QuoteSummary Accessors
```julia
calendar_events(data)
earnings_estimates(data)
earnings_per_share(data)
insider_holders(data)
insider_transactions(data)
institutional_ownership(data)
major_holders_breakdown(data)
recommendation_trend(data)
summary_detail(data)
sector_industry(data)
upgrade_downgrade_history(data)
```

### Types
```julia
SearchResult                # Single search result
SearchResults <: AbstractVector{SearchResult}
NewsItem                    # Single news item
NewsResults <: AbstractVector{NewsItem}
YFinanceError <: Exception  # Error type
```

### Constants
```julia
QUOTE_SUMMARY_ITEMS         # Valid quote summary modules
FUNDAMENTAL_TYPES           # Valid financial statement types
FUNDAMENTAL_INTERVALS       # Valid time intervals
```

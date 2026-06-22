# YFinance.jl v0.3.0 — Redesign Proposal

## Overview

Full breaking redesign to align with Julia naming conventions, remove dead code, implement proper type system, and adopt the Tables.jl data interchange protocol.

---

## 1. Naming Changes

### Functions (drop `get_` prefix, use `snake_case`)

| Old | New |
|-----|-----|
| `get_prices` | `prices` |
| `get_dividends` | `dividends` |
| `get_splits` | `splits` |
| `get_Options` | `options` |
| `get_Fundamental` | `fundamentals` |
| `get_quoteSummary` | `quote_summary` |
| `get_symbols` | `search_symbols` |
| `search_news` | `search_news` (unchanged) |
| `validate_symbol` | `is_valid_symbol` |
| `get_valid_symbols` | `valid_symbols` |
| `get_all_symbols` | **Removed** (third-party API) |
| `get_ESG` | **Removed** (dead endpoint) |
| `get_calendar_events` | `calendar_events` |
| `get_earnings_estimates` | `earnings_estimates` |
| `get_eps` | `eps` |
| `get_insider_holders` | `insider_holders` |
| `get_insider_transactions` | `insider_transactions` |
| `get_institutional_ownership` | `institutional_ownership` |
| `get_major_holders_breakdown` | `major_holders_breakdown` |
| `get_recommendation_trend` | `recommendation_trend` |
| `get_summary_detail` | `summary_detail` |
| `get_sector_industry` | `sector_industry` |
| `get_upgrade_downgrade_history` | `upgrade_downgrade_history` |
| `create_proxy_settings` | `set_proxy` |
| `clear_proxy_settings` | `clear_proxy` |
| `sink_prices_to` | **Removed** (Tables.jl replaces this) |

### Constants

| Old | New |
|-----|-----|
| `_QuoteSummary_Items` | `QUOTE_SUMMARY_ITEMS` |
| `_Fundamental_Types` | `FUNDAMENTAL_TYPES` |
| `_Fundamental_Intervals` | `FUNDAMENTAL_INTERVALS` |
| `_PROXY_SETTINGS` | **Removed** |

### Files (consistent `snake_case.jl`)

| Old | New |
|-----|-----|
| `Prices.jl` | `prices.jl` |
| `Options.jl` | `options.jl` |
| `Fundamental.jl` | `fundamentals.jl` |
| `QuoteSummary.jl` | `quote_summary.jl` |
| `Search_Symbol.jl` | `search.jl` |
| `News_Search.jl` | `news.jl` |
| `Proxy_Auth.jl` | `proxy.jl` |
| `Validity.jl` | `validation.jl` |
| `cookie_and_crumb.jl` | **Merged into `network.jl`** |
| `ESG.jl` | **Deleted** |

---

## 2. Removed Code

| Item | Reason |
|------|--------|
| `ESG.jl` | Yahoo deprecated `/v1/finance/esgChart` endpoint in 2023 |
| `get_all_symbols` | Uses `dumbstockapi.com`, not Yahoo Finance — unreliable third-party |
| `_PROXY_SETTINGS` global | Legacy artifact; session already holds proxy state |
| `cookie_and_crumb.jl` | 5 one-liners merged into `network.jl` |
| `ext/YFinance_TimeSeries.jl` | Replaced by Tables.jl interface |
| `ext/YFinance_TSFrames.jl` | Replaced by Tables.jl interface |
| `sink_prices_to` | Replaced by Tables.jl interface |

---

## 3. New Type System

### Exception Type
```julia
struct YFinanceError <: Exception
    symbol::String
    message::String
    status::Union{Nothing, Int}
end
```

All functions throw `YFinanceError` on failure. No more `throw_error::Bool` pattern.
This is the standard Julia idiom — users handle with `try/catch`.

### Return Types (all implement Tables.jl)

```julia
struct PriceData
    ticker::String
    timestamp::Vector{DateTime}
    open::Vector{Float64}
    high::Vector{Float64}
    low::Vector{Float64}
    close::Vector{Float64}
    volume::Vector{Float64}
    adjclose::Union{Nothing, Vector{Float64}}
end

struct DividendData
    ticker::String
    timestamp::Vector{DateTime}
    dividend::Vector{Float64}
end

struct SplitData
    ticker::String
    timestamp::Vector{DateTime}
    numerator::Vector{Int}
    denominator::Vector{Int}
    ratio::Vector{Float64}
end

struct OptionsChain
    ticker::String
    calls::OptionSide
    puts::OptionSide
end

struct OptionSide  # implements Tables.jl
    data::OrderedDict{String, Vector}
end

struct FundamentalData  # implements Tables.jl
    ticker::String
    data::OrderedDict{String, Vector}
end
```

### Tables.jl Interface

All result types implement `Tables.istable`, `Tables.columnaccess`, `Tables.columns`, `Tables.columnnames`, `Tables.getcolumn`. This means:

```julia
using DataFrames
prices("AAPL") |> DataFrame          # Just works
dividends("AAPL") |> DataFrame       # Just works
fundamentals("AAPL", ...) |> DataFrame  # Just works

using CSV
CSV.write("prices.csv", prices("AAPL"))  # Just works
```

---

## 4. Error Handling Philosophy

**Always throw.** This is the Julia way.

- `HTTP.jl` throws on errors
- `JSON.jl` throws on parse failures
- `CSV.jl` throws on malformed data
- Production Julia code uses `try/catch`

Benefits:
- Errors are never silently swallowed
- Stack traces preserved for debugging
- Return types are stable (no `Union{Nothing, ...}`)
- Cleaner API (fewer kwargs)

```julia
# Before (Python-ish)
data = get_prices("INVALID"; throw_error=false)  # silently returns empty dict

# After (Julian)
try
    data = prices("INVALID")
catch e::YFinanceError
    @warn "Failed: $(e.message)"
end
```

---

## 5. Centralized Symbol Validation

Instead of copy-pasting 10 lines in every function:

```julia
function _validated_symbol(symbol::AbstractString)
    is_valid_symbol(symbol) || throw(YFinanceError(symbol, "Invalid symbol", nothing))
    return symbol
end
```

---

## 6. New File Structure

```
src/
  YFinance.jl          # Module definition + exports
  types.jl             # Exception + all result struct definitions
  tables.jl            # Tables.jl interface implementations
  constants.jl         # FUNDAMENTAL_TYPES, FUNDAMENTAL_INTERVALS, QUOTE_SUMMARY_ITEMS
  headers.jl           # Browser UA headers
  network.jl           # Session, HTTP, cookie/crumb, rate limiting
  proxy.jl             # set_proxy / clear_proxy
  validation.jl        # is_valid_symbol, valid_symbols
  prices.jl            # prices, dividends, splits
  quote_summary.jl     # quote_summary + all accessor functions
  fundamentals.jl      # fundamentals
  options.jl           # options
  search.jl            # search_symbols
  news.jl              # search_news
```

---

## 7. Dependencies Change

### Added
- `Tables.jl` — standard Julia data interchange protocol

### Removed (weakdeps)
- `TSFrames`
- `TimeSeries`

---

## 8. Version

**0.3.0** — Breaking release. All public API renamed.

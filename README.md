<p align="center">
  <img src="Logo/Logo.jpg" width="220" alt="YFinance.jl"/>
</p>

<h1 align="center">YFinance.jl</h1>

<p align="center">
  <em>Fast, typed Yahoo Finance API client for Julia</em>
</p>

<p align="center">
  <a href="https://github.com/eohne/YFinance.jl/actions"><img src="https://img.shields.io/github/actions/workflow/status/eohne/YFinance.jl/CI.yml?branch=master&style=flat-square" alt="CI"/></a>
  <a href="https://eohne.github.io/YFinance.jl/dev/"><img src="https://img.shields.io/badge/docs-dev-blue?style=flat-square" alt="Docs"/></a>
  <img src="https://img.shields.io/badge/julia-%E2%89%A5%201.10-blue?style=flat-square" alt="Julia 1.10+"/>
</p>

---

## Features

- **Typed return structs** — `PriceData`, `DividendData`, `SplitData`, `OptionChain` with full type stability
- **Tables.jl interface** — Pipe directly to DataFrames: `get_prices("AAPL") |> DataFrame`
- **Minimal dependencies** — Only JSON.jl and Tables.jl (+ stdlib)
- **Rate-limit handling** — Automatic retry with exponential backoff
- **Thread-safe** — Singleton session with `ReentrantLock`

## Installation

```julia
using Pkg
Pkg.add("YFinance")
```

## Quick Start

```julia
using YFinance

# Stock prices (returns PriceData struct)
prices = get_prices("AAPL", range="1mo")
prices.close      # Vector{Float64}
prices.timestamp  # Vector{DateTime}

# Direct to DataFrame
using DataFrames
get_prices("AAPL", range="5d") |> DataFrame
```

## API Reference

### Prices

```julia
get_prices(symbol; range="5d", interval="1d", startdt="", enddt="",
           prepost=false, autoadjust=true, divsplits=false,
           exchange_local_time=false, timeout=10, throw_error=false)
```

Returns `PriceData` with fields: `ticker`, `timestamp`, `open`, `high`, `low`, `close`, `adjclose`, `volume`, `dividend`, `split_ratio`.

```julia
# By range
get_prices("MSFT", range="1y", interval="1d")

# By date range
get_prices("TSLA", startdt="2024-01-01", enddt="2024-06-01")

# Intraday
get_prices("NVDA", range="5d", interval="5m")

# With dividends and splits
get_prices("GOOGL", range="5y", divsplits=true, autoadjust=false)

# Broadcasting
get_prices.(["AAPL", "MSFT", "GOOGL"], range="1mo")
```

### Dividends & Splits

```julia
get_dividends(symbol; startdt="", enddt="")  # → DividendData
get_splits(symbol; startdt="", enddt="")     # → SplitData
```

```julia
divs = get_dividends("AAPL", startdt="2020-01-01", enddt="2024-01-01")
divs.dividend   # Vector{Float64}
divs |> DataFrame

splits = get_splits("AAPL", startdt="2000-01-01")
splits.ratio    # Vector{Float64}
```

### Options

```julia
get_options(symbol; throw_error=false, expdate=nothing)  # → OptionChain
```

```julia
chain = get_options("AAPL")
chain.calls   # Vector{OptionContract}
chain.puts    # Vector{OptionContract}
chain |> DataFrame  # All contracts as table
```

### Fundamentals

```julia
get_fundamentals(symbol, item, interval, startdt, enddt)  # → Dict{String,Vector}
```

```julia
# Full income statement
data = get_fundamentals("AAPL", "income_statement", "annual", "2020-01-01", "2024-01-01")

# Single line item
rev = get_fundamentals("AAPL", "TotalRevenue", "quarterly", "2022-01-01", "2024-01-01")

# Available statements: "income_statement", "balance_sheet", "cash_flow", "valuation"
# See all items: FUNDAMENTAL_TYPES
```

### Quote Summary

```julia
get_quote_summary(symbol; item=nothing)  # → Dict{String,Any}
```

```julia
qs = get_quote_summary("AAPL")

# Accessor functions (accept Dict or String)
calendar_events(qs)
earnings_estimates(qs)
earnings_per_share(qs)
insider_holders(qs)
insider_transactions(qs)
institutional_ownership(qs)
major_holders_breakdown(qs)
recommendation_trend(qs)
summary_detail(qs)
sector_industry(qs)
upgrade_downgrade_history(qs)

# Or pass symbol directly
sector_industry("AAPL")
```

### Search

```julia
search_symbols("microsoft")  # → SearchResults
search_news("AAPL")          # → NewsResults
```

```julia
results = search_symbols("tesla")
results[1].symbol  # "TSLA"
results[1].name    # "Tesla, Inc."

news = search_news("AAPL")
titles(news)       # Vector{String}
links(news)        # Vector{String}
```

### Validation

```julia
is_valid_symbol("AAPL")                    # true
valid_symbols(["AAPL", "FAKE", "MSFT"])    # ["AAPL", "MSFT"]
```

### Proxy Configuration

```julia
set_proxy!("http://proxy.example.com:8080")
set_proxy!("http://proxy.example.com:8080", "user", "password")
clear_proxy!()
```

## Return Types

| Function | Return Type | Tables.jl |
|----------|------------|-----------|
| `get_prices` | `PriceData` | ✓ |
| `get_dividends` | `DividendData` | ✓ |
| `get_splits` | `SplitData` | ✓ |
| `get_options` | `OptionChain` | ✓ |
| `get_fundamentals` | `Dict{String,Vector}` | — |
| `get_quote_summary` | `Dict{String,Any}` | — |
| `search_symbols` | `SearchResults` | — |
| `search_news` | `NewsResults` | — |

All Tables.jl-compatible types can be piped directly to `DataFrame`.

## Design Decisions

**Why typed structs instead of Dict?**
- Type stability enables JIT optimization ([Julia Performance Tips](https://docs.julialang.org/en/v1/manual/performance-tips/))
- IDE autocomplete on fields (`.close`, `.volume`, etc.)
- Clear API contract — you know exactly what you'll get back
- Still works with `|> DataFrame` via Tables.jl interface

**Why Dict for fundamentals/quote summary?**
- Schema is user-defined (300+ possible fields for fundamentals)
- Each quote summary module has different structure
- Dict is the natural representation for dynamic JSON data

## License

MIT

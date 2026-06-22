<div align="center">
  <img src="Logo/Logo.jpg" alt="YFinance.jl" width="200"/>
  <h1>YFinance.jl</h1>
  <p><strong>Yahoo Finance data in Julia — fast, typed, and Tables.jl-native.</strong></p>

  [![Build Status](https://github.com/eohne/YFinance.jl/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/eohne/YFinance.jl/actions/workflows/CI.yml?query=branch%3Amaster)
  [![codecov](https://codecov.io/github/eohne/YFinance.jl/graph/badge.svg?token=MYY3JY9HBH)](https://codecov.io/github/eohne/YFinance.jl)
  [![Docs Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://eohne.github.io/YFinance.jl/stable/)
  [![Docs Dev](https://img.shields.io/badge/docs-dev-purple.svg)](https://eohne.github.io/YFinance.jl/dev/)
  [![Downloads](https://img.shields.io/badge/dynamic/json?url=http%3A%2F%2Fjuliapkgstats.com%2Fapi%2Fv1%2Ftotal_downloads%2FYFinance&query=total_requests&label=Downloads)](http://juliapkgstats.com/pkg/YFinance)
  [![Julia Version](https://img.shields.io/badge/Julia-1.10%2B-blue?logo=julia)](https://julialang.org/)
</div>

---

## Features

| Category | What you get |
|----------|-------------|
| **Prices** | OHLCV for equities, ETFs, FX, futures, crypto — 1m to monthly intervals |
| **Dividends & Splits** | Full dividend and stock-split history |
| **Fundamentals** | Income statement, balance sheet, cash flow, valuation multiples |
| **Options** | Full options chain (calls + puts) by expiration date |
| **Quote Summary** | 30+ modules: earnings, insider activity, sector/industry, recommendations, etc. |
| **Search & News** | Symbol search and multi-language news articles |

All return types implement the **[Tables.jl](https://github.com/JuliaData/Tables.jl)** interface — pipe directly into `DataFrame`, `CSV.write`, or any Tables-compatible sink.

---

## Installation

```julia
using Pkg
Pkg.add("YFinance")
```

## Quick Start

```julia
using YFinance, DataFrames

# Historical prices → DataFrame in one line
prices("AAPL", range="1mo") |> DataFrame

# Dividends
dividends("AAPL", startdt="2020-01-01", enddt="2024-01-01") |> DataFrame

# Stock splits
splits("AAPL", startdt="2000-01-01") |> DataFrame

# Fundamentals
fundamentals("AAPL", "income_statement", "annual", "2022-01-01", "2024-01-01") |> DataFrame

# Options chain
chain = options("AAPL")
chain.calls |> DataFrame
chain.puts  |> DataFrame

# Quote summary
quote_summary("AAPL", item="summaryDetail")

# Search
search_symbols("artificial intelligence")

# News
search_news("TSLA")
```

---

## Architecture

YFinance.jl is built on Julia's stdlib `Downloads.jl` (libcurl) — **no external HTTP package required**.

```
┌──────────────────────────────────────────────────────┐
│  User API                                            │
│  prices() · dividends() · options() · fundamentals() │
├──────────────────────────────────────────────────────┤
│  Types + Tables.jl                                   │
│  PriceData · DividendData · OptionsChain · ...       │
├──────────────────────────────────────────────────────┤
│  Network Layer                                       │
│  Connection Pool · Rate Limit · Retry · Session Auth │
├──────────────────────────────────────────────────────┤
│  Downloads.jl (libcurl)                              │
└──────────────────────────────────────────────────────┘
```

**Key design decisions:**

- **Connection pooling** — persistent `Downloader` reuses TCP/TLS connections
- **Rate limiting** — automatic 300ms throttle between requests
- **Exponential backoff** — retries on 429/transient failures
- **Thread-safe session** — cookie/crumb auth with auto-renewal on 401/403
- **Typed returns** — `PriceData`, `SplitData`, `OptionsChain`, etc. (no untyped dicts)
- **Always-throw errors** — `YFinanceError` with symbol, message, HTTP status

---

## Return Types

| Function | Returns | Tables.jl |
|----------|---------|:---------:|
| `prices()` | `PriceData` | ✓ |
| `dividends()` | `DividendData` | ✓ |
| `splits()` | `SplitData` | ✓ |
| `fundamentals()` | `FundamentalData` | ✓ |
| `options()` | `OptionsChain` (.calls/.puts → `OptionSide`) | ✓ |
| `search_symbols()` | `SearchResults` | — |
| `search_news()` | `NewsResults` | — |
| `quote_summary()` | `Dict{String,Any}` | — |

Since all tabular types implement Tables.jl, they work with:
- **DataFrames.jl** — `prices("AAPL") |> DataFrame`
- **CSV.jl** — `CSV.write("data.csv", prices("AAPL"))`
- **Arrow.jl** — `Arrow.write("data.arrow", prices("AAPL"))`
- Any other Tables.jl-compatible sink

---

## Examples

### Intraday Data
```julia
using YFinance, DataFrames

# Bitcoin 5-minute bars for the last day
prices("BTC-USD", range="1d", interval="5m") |> DataFrame
```

### Fundamentals
```julia
# Netflix quarterly income statement
fundamentals("NFLX", "income_statement", "quarterly", "2022-01-01", "2024-01-01") |> DataFrame

# Single metric
fundamentals("AAPL", "TotalRevenue", "annual", "2020-01-01", "2024-01-01") |> DataFrame
```

### Options Chain
```julia
chain = options("TSLA")
chain.calls |> DataFrame  # All call contracts
chain.puts  |> DataFrame  # All put contracts
```

### Analyst Recommendations
```julia
recommendation_trend("AAPL")
# OrderedDict with period, strong_buy, buy, hold, sell, strong_sell
```

### News Search
```julia
news = search_news("NVDA")
titles(news)      # Vector of headlines
links(news)       # Vector of article URLs
timestamps(news)  # Vector of DateTime
```

---

## API Reference

### Data Retrieval

| Function | Description |
|----------|-------------|
| `prices(symbol; ...)` | OHLCV price data |
| `dividends(symbol; ...)` | Dividend history |
| `splits(symbol; ...)` | Stock split history |
| `fundamentals(symbol, item, interval, startdt, enddt)` | Financial statements |
| `options(symbol; ...)` | Options chain |
| `quote_summary(symbol; item)` | Quote summary modules |
| `search_symbols(query)` | Symbol search |
| `search_news(query; lang)` | News articles |

### Quote Summary Accessors

| Function | Description |
|----------|-------------|
| `calendar_events(qs)` | Dividend/earnings dates |
| `earnings_estimates(qs)` | Quarterly earnings estimates |
| `eps(qs)` | EPS history |
| `insider_holders(qs)` | Insider holdings |
| `insider_transactions(qs)` | Insider trades |
| `institutional_ownership(qs)` | Institutional holders |
| `major_holders_breakdown(qs)` | Ownership breakdown |
| `recommendation_trend(qs)` | Analyst consensus |
| `summary_detail(qs)` | Key statistics |
| `sector_industry(qs)` | Sector & industry |
| `upgrade_downgrade_history(qs)` | Rating changes |

All accessors accept either a `Dict` from `quote_summary()` or a ticker string directly.

### Configuration

| Function | Description |
|----------|-------------|
| `set_proxy(url; user, password)` | Configure proxy |
| `clear_proxy()` | Remove proxy |
| `is_valid_symbol(symbol)` | Check ticker validity |
| `valid_symbols(symbols)` | Filter valid tickers |

### Constants

| Constant | Description |
|----------|-------------|
| `QUOTE_SUMMARY_ITEMS` | Valid quote summary module names |
| `FUNDAMENTAL_TYPES` | Statement types and sub-items |
| `FUNDAMENTAL_INTERVALS` | Valid intervals (annual/quarterly/monthly) |

---

## Error Handling

YFinance.jl follows the Julia convention of throwing exceptions:

```julia
try
    data = prices("INVALID_TICKER_XYZ")
catch e::YFinanceError
    println("Symbol: ", e.symbol)
    println("Message: ", e.message)
    println("HTTP Status: ", e.status)
end
```

---

## Legal Disclaimer

**Yahoo!, Y!Finance, and Yahoo! Finance are registered trademarks of Yahoo, Inc.**

YFinance.jl is **not** endorsed by or affiliated with Yahoo, Inc. Data retrieved is for **personal use only**. Please review:

- [Yahoo Developer API Terms of Use](https://policies.yahoo.com/us/en/yahoo/terms/product-atos/apiforydn/index.htm)
- [Yahoo Terms of Service](https://legal.yahoo.com/us/en/yahoo/terms/otos/index.html)
- [Yahoo Terms](https://policies.yahoo.com/us/en/yahoo/terms/index.htm)

---

## Contributing

Issues and PRs welcome. Please run tests before submitting:

```julia
using Pkg
Pkg.test("YFinance")
```

---

<div align="center">
  <sub>Built with ♥ in Julia</sub>
</div>

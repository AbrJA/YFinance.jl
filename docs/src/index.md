# YFinance.jl

*Yahoo Finance data in Julia — fast, typed, and Tables.jl-native.*

## Overview

YFinance.jl provides access to Yahoo Finance market data through a clean, Julian API. All tabular results implement the [Tables.jl](https://github.com/JuliaData/Tables.jl) interface, meaning they pipe directly into DataFrames, CSV, Arrow, or any other Tables-compatible sink.

## Key Features

- **Historical & intraday prices** — equities, ETFs, FX, futures, crypto (1m to monthly)
- **Dividends & stock splits** — full history with typed return structs
- **Fundamentals** — income statement, balance sheet, cash flow, valuation multiples
- **Options chains** — calls and puts by expiration date
- **Quote summary** — 30+ modules (earnings, insider activity, sector/industry, etc.)
- **Symbol search & news** — find tickers and related articles in multiple languages
- **Always-throw errors** — `YFinanceError` with symbol, message, and HTTP status
- **Zero external HTTP deps** — built on Julia's stdlib `Downloads.jl` (libcurl)

## Quick Start

```julia
using YFinance, DataFrames

# Prices
prices("AAPL", range="1mo") |> DataFrame

# Dividends
dividends("AAPL", startdt="2020-01-01", enddt="2024-01-01") |> DataFrame

# Fundamentals
fundamentals("AAPL", "income_statement", "annual", "2022-01-01", "2024-01-01") |> DataFrame

# Options
chain = options("AAPL")
chain.calls |> DataFrame
```

## Installation

```julia
using Pkg
Pkg.add("YFinance")
```

## Legal Disclaimer

**Yahoo!, Y!Finance, and Yahoo! Finance are registered trademarks of Yahoo, Inc.**

YFinance.jl is not endorsed by or affiliated with Yahoo, Inc. Data is for personal use only. See [Yahoo Terms of Service](https://legal.yahoo.com/us/en/yahoo/terms/otos/index.html).

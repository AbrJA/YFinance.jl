# YFinance.jl

[![Build Status](https://github.com/eohne/YFinance.jl/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/eohne/YFinance.jl/actions/workflows/CI.yml?query=branch%3Amaster)
[![codecov](https://codecov.io/github/eohne/YFinance.jl/graph/badge.svg?token=MYY3JY9HBH)](https://codecov.io/github/eohne/YFinance.jl)

Julia interface to Yahoo Finance API.

## Features

- Historical and intraday prices (equities, FX, futures, ETFs, mutual funds, crypto)
- Fundamentals (income statement, balance sheet, cash flow, valuations)
- Options chains (calls/puts by expiration)
- Quote summary data (sector, industry, earnings, insider activity, etc.)
- Symbol search and news
- Tables.jl interface — pipe directly to `DataFrame`

## Installation

```julia
using Pkg
Pkg.add("YFinance")
```

## Quick Start

```julia
using YFinance, DataFrames

# Get 1 month of daily prices
get_prices("AAPL", range="1mo") |> YFinanceTable |> DataFrame

# Search for symbols
search_symbols("microsoft")

# Get fundamentals
get_fundamentals("AAPL", "income_statement", "annual", "2020-01-01", "2024-01-01")

# Options chain
get_options("AAPL")

# Quote summary
data = get_quote_summary("AAPL")
sector_industry(data)
recommendation_trend(data)
```

## API Reference

### Price Data

```julia
get_prices(symbol; startdt, enddt, range, interval, autoadjust, exchange_local_time, divsplits, throw_error)
get_dividends(symbol; startdt, enddt, throw_error)
get_splits(symbol; startdt, enddt, throw_error)
```

### Fundamental Data

```julia
get_fundamentals(symbol, item, interval, startdt, enddt; throw_error)
# item: "income_statement", "balance_sheet", "cash_flow", "valuation", or individual fields
# interval: "annual", "quarterly", "monthly"
```

### Options

```julia
get_options(symbol; throw_error, expiration_date)
```

### Quote Summary

```julia
get_quote_summary(symbol; item, throw_error)

# Accessor functions (work on the dict returned by get_quote_summary, or accept a symbol directly):
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

### Search

```julia
search_symbols(query)  # -> SearchResults
search_news(query; lang)  # -> NewsResults
```

### Validation

```julia
is_valid_symbol(symbol)  # -> Bool
valid_symbols(symbols)   # -> filtered vector
```

### Configuration

```julia
set_proxy!(url, user, password)
clear_proxy!()
```

### Tables.jl Integration

All `OrderedDict` results can be wrapped in `YFinanceTable` for Tables.jl compatibility:

```julia
using DataFrames
get_prices("AAPL", range="5d") |> YFinanceTable |> DataFrame
get_fundamentals("AAPL", "TotalRevenue", "quarterly", "2020-01-01", "2024-01-01") |> YFinanceTable |> DataFrame
```

### Constants

```julia
QUOTE_SUMMARY_ITEMS    # Valid modules for get_quote_summary
FUNDAMENTAL_TYPES      # Valid financial statement types and fields
FUNDAMENTAL_INTERVALS  # Valid intervals: "annual", "quarterly", "monthly"
```

## Legal Disclaimer

**Yahoo!, Y!Finance, and Yahoo! finance are registered trademarks of Yahoo, Inc.**

YFinance.jl is not endorsed or affiliated with Yahoo, Inc. Data retrieved is for personal use only. See Yahoo's terms of use:

- [Yahoo Developer API Terms of Use](https://policies.yahoo.com/us/en/yahoo/terms/product-atos/apiforydn/index.htm)
- [Yahoo Terms of Service](https://legal.yahoo.com/us/en/yahoo/terms/otos/index.html)

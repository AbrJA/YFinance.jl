# YFinance.jl
GitHub Repo: [https://github.com/eohne/YFinance.jl](https://github.com/eohne/YFinance.jl)

*Download price, fundamental, and option data from Yahoo Finance*

## Features

- **Historical & intraday prices** — equities, FX, futures, ETFs, mutual funds, crypto
- **Fundamentals** — income statement, balance sheet, cash flow, valuations
- **Options chains** — calls/puts by expiration date
- **Quote summary** — sector, industry, earnings, insider activity, and more
- **Symbol search & news** — find tickers and related news articles
- **DataFrame integration** — all results convert directly to DataFrames, TimeArrays, or TSFrames

## Architecture

YFinance.jl uses Julia's stdlib `Downloads.jl` (libcurl) for HTTP — no external HTTP package needed:

- **Connection pooling** — persistent `Downloader` reuses TCP connections
- **Rate limiting** — automatic throttle (300ms) between requests to avoid Yahoo 429 errors
- **Retry with exponential backoff** — handles transient failures automatically
- **Thread-safe session** — cookie/crumb authentication with auto-renewal on 401/403
- **Minimal dependencies** — only JSON3, OrderedCollections, and PrecompileTools

## *** LEGAL DISCLAIMER ***
**Yahoo!, Y!Finance, and Yahoo! finance are registered trademarks of
Yahoo, Inc.**

YFinance.jl is not endorsed or in any way affiliated with Yahoo, Inc. The data retrieved can only be used for personal use.
Please see Yahoo's terms of use to ensure that you can use the data:
 - [Yahoo Developer API Terms of Use](https://policies.yahoo.com/us/en/yahoo/terms/product-atos/apiforydn/index.htm)
 - [Yahoo Terms of Service](https://legal.yahoo.com/us/en/yahoo/terms/otos/index.html)
 - [Yahoo Terms](https://policies.yahoo.com/us/en/yahoo/terms/index.htm)

## *** No decryption issues ***
The implementation of `YFinance.jl` is similar to the python package `yahooquery` in that it accesses data through API endpoints. Therefore, **`YFinance.jl` does not experience the same decryption issues** that python's `yfinance` faces at the moment.

## What you can download
- Price data (including intraday, up to 1-minute resolution for the last 30 days)
- Fundamental data (income statement, balance sheet, cash flow, valuations)
- Option data (calls and puts with Greeks)
- quoteSummary data (a JSON3 object with comprehensive company information)
- Symbol search results
- Financial news

## Installation

The package is registered in the [`General`](https://github.com/JuliaRegistries/General) registry.

```julia
] add YFinance
```
Or:
```julia
using Pkg
Pkg.add("YFinance")
```

Then load:
```julia
using YFinance
```

**Requirements:** Julia 1.10+

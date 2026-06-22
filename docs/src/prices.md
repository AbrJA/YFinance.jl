# Prices

## `get_prices`

Retrieve OHLCV price data. Returns a [`PriceData`](@ref) struct (Tables.jl compatible).

```@docs
get_prices
```

### Examples

```julia
# Daily prices for the last 5 days
prices = get_prices("AAPL", range="5d")
prices.close      # Vector{Float64}
prices.timestamp  # Vector{DateTime}

# Date range
prices = get_prices("MSFT", startdt="2024-01-01", enddt="2024-06-01")

# Intraday (5-minute bars)
prices = get_prices("NVDA", range="5d", interval="5m")

# With dividends and splits
prices = get_prices("AAPL", range="5y", divsplits=true, autoadjust=false)

# Pre/post market data
prices = get_prices("TSLA", range="1d", interval="1m", prepost=true)

# Direct to DataFrame
using DataFrames
df = get_prices("AAPL", range="1mo") |> DataFrame

# Multiple symbols
data = get_prices.(["AAPL", "MSFT", "GOOGL"], range="1mo")
```

### Return Type

`PriceData` struct with fields:

| Field | Type | Description |
|-------|------|-------------|
| `ticker` | `String` | Symbol |
| `timestamp` | `Vector{DateTime}` | Bar timestamps |
| `open` | `Vector{Float64}` | Open prices |
| `high` | `Vector{Float64}` | High prices |
| `low` | `Vector{Float64}` | Low prices |
| `close` | `Vector{Float64}` | Close prices |
| `adjclose` | `Vector{Float64}` | Adjusted close |
| `volume` | `Vector{Float64}` | Volume |
| `dividend` | `Vector{Float64}` | Dividends (when `divsplits=true`) |
| `split_ratio` | `Vector{Float64}` | Split ratios (when `divsplits=true`) |

### Valid Intervals

`"1m"`, `"2m"`, `"5m"`, `"15m"`, `"30m"`, `"60m"`, `"90m"`, `"1h"`, `"1d"`, `"5d"`, `"1wk"`, `"1mo"`, `"3mo"`

!!! note "Intraday data"
    Minute-level data is only available for the last 30 days. Requests older than 30 days will return empty results or a warning.

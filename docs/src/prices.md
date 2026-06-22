# Prices

## `prices`

Retrieve historical OHLCV price data.

```@docs
prices
```

### Examples

```julia
using YFinance, DataFrames

# Daily prices for the last month
prices("AAPL", range="1mo") |> DataFrame

# 5-minute intraday data
prices("TSLA", range="1d", interval="5m") |> DataFrame

# Custom date range
prices("MSFT", startdt="2023-01-01", enddt="2024-01-01") |> DataFrame

# Pre/post market data
prices("AAPL", range="1d", interval="5m", prepost=true) |> DataFrame

# Exchange local time
prices("RR.L", range="5d", exchange_local_time=true) |> DataFrame

# Broadcasting over multiple symbols
prices.(["AAPL", "MSFT", "GOOG"], range="5d")
```

## `dividends`

Retrieve dividend history.

```@docs
dividends
```

### Examples

```julia
using YFinance, DataFrames

dividends("AAPL", startdt="2020-01-01", enddt="2024-01-01") |> DataFrame

# All available history
dividends("KO") |> DataFrame
```

## `splits`

Retrieve stock split history.

```@docs
splits
```

### Examples

```julia
using YFinance, DataFrames

splits("AAPL", startdt="2000-01-01") |> DataFrame
splits("TSLA") |> DataFrame
```

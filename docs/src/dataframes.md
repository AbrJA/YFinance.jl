# DataFrames & Tables

YFinance.jl implements the [Tables.jl](https://github.com/JuliaData/Tables.jl) interface,
so all primary data types can be piped directly into any Tables.jl-compatible sink.

## Basic Usage

```julia
using YFinance, DataFrames

# Prices → DataFrame
df = get_prices("AAPL", range="1mo") |> DataFrame

# Dividends → DataFrame
divs = get_dividends("MSFT", startdt="2020-01-01") |> DataFrame

# Splits → DataFrame
splits = get_splits("GOOGL", startdt="2000-01-01") |> DataFrame

# Options → DataFrame (concatenates calls + puts)
options = get_options("AAPL") |> DataFrame
```

## Working with Price Data

```julia
using YFinance, DataFrames, Statistics

df = get_prices("AAPL", range="1y") |> DataFrame

# Simple moving average
df.sma_20 = [i < 20 ? NaN : mean(df.close[i-19:i]) for i in 1:nrow(df)]

# Daily returns
df.returns = [i == 1 ? 0.0 : (df.close[i] - df.close[i-1]) / df.close[i-1] for i in 1:nrow(df)]

# Filter by date
recent = filter(r -> r.timestamp > DateTime(2024, 6, 1), df)
```

## Multiple Symbols

```julia
using YFinance, DataFrames

symbols = ["AAPL", "MSFT", "GOOGL", "AMZN"]
dfs = [get_prices(s, range="1mo") |> DataFrame for s in symbols]

# Or using broadcasting
data = get_prices.(symbols, range="1mo")
```

## CSV Export

```julia
using YFinance, DataFrames, CSV

df = get_prices("AAPL", range="1y") |> DataFrame
CSV.write("aapl_prices.csv", df)
```

## Compatible Types

| Function | Tables.jl | Pipe to DataFrame |
|----------|-----------|-------------------|
| `get_prices` | ✓ | `get_prices("AAPL") \|> DataFrame` |
| `get_dividends` | ✓ | `get_dividends("AAPL") \|> DataFrame` |
| `get_splits` | ✓ | `get_splits("AAPL") \|> DataFrame` |
| `get_options` | ✓ | `get_options("AAPL") \|> DataFrame` |

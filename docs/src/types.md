# Types Reference

All tabular return types implement the [Tables.jl](https://github.com/JuliaData/Tables.jl) interface.

## Price Types

```@docs
PriceData
DividendData
SplitData
```

## Options Types

```@docs
OptionsChain
OptionSide
```

## Fundamental Types

```@docs
FundamentalData
```

## Search & News Types

```@docs
SearchResult
SearchResults
NewsItem
NewsResults
```

## Error Type

```@docs
YFinanceError
```

## Using with DataFrames

Since all tabular types implement Tables.jl, conversion is zero-cost:

```julia
using YFinance, DataFrames

# Any of these work:
prices("AAPL", range="5d") |> DataFrame
dividends("AAPL") |> DataFrame
splits("AAPL") |> DataFrame
fundamentals("AAPL", "valuation", "annual", "2020-01-01", "2024-01-01") |> DataFrame
options("AAPL").calls |> DataFrame
```

## Using with CSV

```julia
using YFinance, CSV

CSV.write("aapl_prices.csv", prices("AAPL", range="1y"))
CSV.write("aapl_dividends.csv", dividends("AAPL"))
```

# Plotting

Examples using [Plots.jl](https://github.com/JuliaPlots/Plots.jl) with YFinance data.

## Setup

```julia
using YFinance, DataFrames, Dates, Plots
```

## Price Chart

```julia
prices = get_prices("AAPL", range="6mo")

plot(prices.timestamp, prices.close,
     label="AAPL Close", xlabel="Date", ylabel="Price (USD)",
     title="Apple — 6 Month Price", linewidth=2)
```

## Candlestick Chart (using StatsPlots)

```julia
using StatsPlots

df = get_prices("AAPL", range="1mo") |> DataFrame

# StatsPlots @df macro
@df df plot(:timestamp, [:open :high :low :close],
            seriestype=:candlestick, title="AAPL Candlestick")
```

## Volume Chart

```julia
prices = get_prices("MSFT", range="3mo")

p1 = plot(prices.timestamp, prices.close, label="Close", ylabel="Price")
p2 = bar(prices.timestamp, prices.volume, label="Volume", ylabel="Volume", alpha=0.5)
plot(p1, p2, layout=(2, 1), title="MSFT — Price & Volume")
```

## Multiple Symbols Comparison

```julia
symbols = ["AAPL", "MSFT", "GOOGL"]
p = plot(title="Tech Comparison (Normalized)", ylabel="Return %")

for sym in symbols
    prices = get_prices(sym, range="1y")
    returns = (prices.close ./ prices.close[1] .- 1) .* 100
    plot!(p, prices.timestamp, returns, label=sym, linewidth=2)
end
display(p)
```

## Dividend History

```julia
divs = get_dividends("KO", startdt="2015-01-01")

bar(divs.timestamp, divs.dividend,
    label="Dividend", title="Coca-Cola Dividends",
    xlabel="Date", ylabel="Dividend (USD)")
```

# Dividends & Splits

## `get_dividends`

Retrieve dividend history. Returns a [`DividendData`](@ref) struct (Tables.jl compatible).

```@docs
get_dividends
```

### Examples

```julia
divs = get_dividends("AAPL", startdt="2020-01-01", enddt="2024-01-01")
divs.timestamp  # Vector{DateTime}
divs.dividend   # Vector{Float64}

# All historical dividends
divs = get_dividends("KO")

# Direct to DataFrame
using DataFrames
get_dividends("MSFT") |> DataFrame
```

---

## `get_splits`

Retrieve stock split history. Returns a [`SplitData`](@ref) struct (Tables.jl compatible).

```@docs
get_splits
```

### Examples

```julia
splits = get_splits("AAPL", startdt="2000-01-01")
splits.timestamp    # Vector{DateTime}
splits.numerator    # Vector{Int} — e.g. 4
splits.denominator  # Vector{Int} — e.g. 1
splits.ratio        # Vector{Float64} — e.g. 4.0

# Direct to DataFrame
using DataFrames
get_splits("GOOGL") |> DataFrame
```

# Options

## `get_options`

Fetch options chain from Yahoo Finance. Returns an [`OptionChain`](@ref) struct (Tables.jl compatible).

```@docs
get_options
```

### Examples

```julia
chain = get_options("AAPL")
chain.calls  # Vector{OptionContract}
chain.puts   # Vector{OptionContract}

# Access individual contract fields
chain.calls[1].strike
chain.calls[1].implied_vol
chain.calls[1].in_the_money

# Filter by expiration
chain = get_options("AAPL", expdate=Date(2025, 1, 17))

# Direct to DataFrame (all contracts)
using DataFrames
df = get_options("AAPL") |> DataFrame
```

### `OptionContract` Fields

| Field | Type | Description |
|-------|------|-------------|
| `symbol` | `String` | Contract symbol |
| `strike` | `Float64` | Strike price |
| `currency` | `String` | Currency (e.g. "USD") |
| `last_price` | `Float64` | Last traded price |
| `change` | `Float64` | Price change |
| `percent_change` | `Float64` | Percent change |
| `volume` | `Union{Missing,Int}` | Trading volume |
| `open_interest` | `Union{Missing,Int}` | Open interest |
| `bid` | `Float64` | Bid price |
| `ask` | `Float64` | Ask price |
| `contract_size` | `String` | Contract size (e.g. "REGULAR") |
| `expiration` | `DateTime` | Expiration date |
| `last_trade` | `DateTime` | Last trade date |
| `implied_vol` | `Float64` | Implied volatility |
| `in_the_money` | `Bool` | Whether contract is ITM |
| `type` | `String` | "call" or "put" |

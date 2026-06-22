# Options

## `options`

Retrieve the full options chain (calls and puts) for a symbol.

```@docs
options
```

### Examples

```julia
using YFinance, DataFrames

chain = options("AAPL")

# Calls
chain.calls |> DataFrame

# Puts
chain.puts |> DataFrame

# With specific expiration date
using Dates
chain = options("AAPL", expiration_date=Date(2024, 3, 15))
```

## Types

```@docs
OptionsChain
OptionSide
```
